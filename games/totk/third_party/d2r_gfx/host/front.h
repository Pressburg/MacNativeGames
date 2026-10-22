#pragma once
#include <stdint.h>
void *front_metal_layer(void);
void front_frame_presented(void);
uint64_t front_game_res(int docked);
int front_display_hz(void);      // 有窗口时游戏所在屏幕的当前刷新率（Hz），无窗口 0 | The current refresh rate (Hz) of the screen the game is on, 0 without a window
