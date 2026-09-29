# macOS 异步限帧多等一帧预算

`OS_MacOS::add_frame_delay` 的 AX/Magnet 分支取 `get_frame_delay()` 后，从当前时间安排完整的定时器。该 getter 返回目标帧周期，并没有减掉已经执行的模拟和渲染时间；普通 `OS::add_frame_delay` 则会计算剩余预算。结果是即使帧率低于上限，每帧仍额外等待约 9 ms。

独立 PoC `tools/frame_wait_poc.gd` 不加载游戏：120 FPS 上限、关闭 VSync，每帧在主线程执行固定 25 ms 的工作，丢弃前 20 帧，测量后 100 帧。M2、Magnet 运行中、640×360 窗口：

| 时间 | 原引擎 | 修复后 |
| --- | ---: | ---: |
| 帧间等待均值 | 9.075 ms | 0.109 ms |
| 完整帧均值 | 34.696 ms | 25.720 ms |
| 完整帧 P95 | 35.099 ms | 25.875 ms |

修复使用引擎当前帧开始时间扣除已用预算；显式固定 `frame_delay_msec` 仍按毫秒保留。原来的 AX 事件处理与等待期间禁止重复渲染的保护保持不变。空工作量对照平均 9.017 ms/帧，没有变成不限速忙转；macOS 定时器调度和窗口呈现会使实际帧率低于 120 上限。没有把禁用 VSync 或取消上限作为游戏修复。

```sh
make build-macos
make run RUN_ARGS='--script res://tools/frame_wait_poc.gd --windowed --resolution 640x360'
RTS_WAIT_WORK_US=0 make run RUN_ARGS='--script res://tools/frame_wait_poc.gd --windowed --resolution 640x360'
```

这是围攻开销的一部分，不能解释全部低帧率。6 建筑场景还有脚本模拟和约 2500 个绘制调用的 CPU 提交成本。
