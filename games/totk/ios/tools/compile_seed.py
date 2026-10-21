#!/usr/bin/env python3
"""Compile the verified startup MSL seed into device metallibs and refresh its manifest."""
import concurrent.futures, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path

# The options of totk_precise_opts() in nvn_mtl.m: the translated shaders need exactly rounded float arithmetic. The
# offline compiler defaults to fast math ("Default is 'fast'"), which breaks their float integer-division idioms.
METAL_FLAGS=['-fmetal-math-mode=safe']

class CompileError(Exception):
  """One file did not compile: the compiler's own words, and what to do about it."""

  def __init__(self, command, message):
    super().__init__(message)
    self.command = command
    self.message = message

def run(command):
  done=subprocess.run(command,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
  if done.returncode: raise CompileError(command, done.stderr.strip())
  return done

def main():
  seed=Path(sys.argv[1]).resolve(); sdk=sys.argv[2]
  manifest=json.loads((seed/'seed-manifest.json').read_text())
  if manifest.get('chain') is None or not manifest.get('files'): raise SystemExit('invalid shader seed manifest')
  files=sorted(n for n in manifest['files'] if n.endswith('_b.metal'))
  def compile_one(name):
    src=seed/name; air=seed/(name+'.air'); lib=seed/(name.removesuffix('.metal')+'.metallib')
    try:
      run(['xcrun','-sdk',sdk,'metal',*METAL_FLAGS,'-c',str(src),'-o',str(air)])
      run(['xcrun','-sdk',sdk,'metallib',str(air),'-o',str(lib)])
    except CompileError as error:
      raise CompileError(error.command,f'{name}: {error.message}') from None
    air.unlink()
    return lib.name,hashlib.sha256(lib.read_bytes()).hexdigest()
  results=[]
  try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(8,os.cpu_count() or 4)) as pool:
      for i,result in enumerate(pool.map(compile_one,files),1):
          results.append(result)
          if i%100==0: print(f'compiled {i}/{len(files)} iOS metallibs',flush=True)
  except CompileError as error:
    # The compiler's own message says what is missing (an iPhoneOS SDK without the Metal toolchain says
    # "unable to find utility metal"); a traceback of the pool does not. Say it, and say what to do.
    raise SystemExit(f'iOS shader seed: {error.message}\n'
                     f'  command: {" ".join(error.command)}\n'
                     f'The iOS startup shaders are compiled with Xcode\'s Metal toolchain: install it with\n'
                     f'  xcodebuild -downloadComponent MetalToolchain\n'
                     f'and the iPhoneOS SDK (Xcode > Settings > Platforms). A Mac-only build does not need them.') from None
  for name,digest in results: manifest['files'][name]=digest
  manifest['ios_metallibs']=len(results)
  manifest['ios_metal_flags']=' '.join(METAL_FLAGS)   # build_ipa.py reuses the libraries only when these match
  manifest['files']={n:hashlib.sha256((seed/n).read_bytes()).hexdigest() for n in sorted(manifest['files'])}
  (seed/'seed-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
  print(f'compiled {len(results)} iOS metallibs')

if __name__=='__main__': main()
