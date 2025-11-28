import vibrator from '@ohos.vibrator';

enum VibrateType {
  Morse,
  Direct
}

@Entry
@Component
struct Index {
  @State message: string = 'Hello World'
  @State messageDetail: string = 'Hello World'
  // 振动时长（单位：毫秒）
  private vibrationDurations: number[] = [1000, 1500, 800, 2000]
  private vibrationDot: number = 100
  private vibrationDash: number = 3 * this.vibrationDot
  // 两次振动之间的固定间隔（单位：毫秒）
  private intervalTime: number = 1000
  private intervalTimeMorse: number = 1000
  private intervalTimeDirect: number = 100
  // 不同位数振动之间的固定间隔（单位：毫秒）
  private intervalTimeDigit: number = 1000
  // 控制振动序列是否终止（核心：用于中断顺序执行）
  private isAbort: boolean = false

  build() {
    Row() {
      Column({ space: 10 }) {
        Text(this.message)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)

        Text(this.messageDetail)
          .fontSize(25)
          .fontWeight(FontWeight.Normal)

        // 获取当前时间按钮
        Button('get time').onClick(() => {
          const [hour, minute, second] = this.getCurrTimeHMS()
          this.message = `${this.fillTime(hour)}:${this.fillTime(minute)}:${this.fillTime(second)}`;
        })

        // 持续振动2秒按钮
        Button('shake2s').onClick(async () => {
          this.stopAllVibration(); // 终止已有序列
          // 重置终止状态
          this.isAbort = false;
          await this.singleVibrationPromise(2000);
          this.message = '2秒振动结束';
        })

        // 停止所有振动按钮
        Button('stop shake').onClick(() => {
          this.stopAllVibration();
          this.message = '振动序列已终止';
        })

        // 数组序列振动按钮（顺序执行版）
        Button('数组序列振动（顺序执行）')
          .onClick(async () => {
            this.stopAllVibration(); // 重置终止状态+停止振动
            await this.executeArrayVibrationSequential(
              this.vibrationDurations,
              this.intervalTime
            );
          })

        Button('test').onClick(async () => {
          this.stopAllVibration(); // 重置终止状态+停止振动
          await this.executeArrayVibrationSequential(
            this.vibrationDurations,
            this.intervalTime
          );
          await this.wait(2000);
          await this.executeArrayVibrationSequential(
            [100, 1000, 100, 1000],
            this.intervalTime
          );
          await this.wait(2000);
          await this.singleVibrationPromise(2000);
          this.message = '振动结束';
        })

        Button('振动报时（摩斯码）').onClick(async () => {
          await this.vibrateTime(VibrateType.Morse)
        })
        Button('振动报时（直接数字，0长振）').onClick(async () => {
          await this.vibrateTime(VibrateType.Direct)
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }

  private getCurrTimeHMS(): [number, number, number] {
    const nowTime = new Date();
    return [nowTime.getHours(), nowTime.getMinutes(), nowTime.getSeconds()]
  }

  /** 补零函数 */
  private fillTime(time: number): string {
    return time < 10 ? `0${time}` : `${time}`;
  }

  /**
   * 数字转摩斯码，输入只能是0-9数字，输出对应的摩斯码，true代表.，false代表-
   */
  private digital2morse(n: number): [boolean, boolean, boolean, boolean, boolean] {
    switch (n) {
      case 0:
        return [false, false, false, false, false];
      case 1:
        return [true, false, false, false, false];
      case 2:
        return [true, true, false, false, false];
      case 3:
        return [true, true, true, false, false];
      case 4:
        return [true, true, true, true, false];
      case 5:
        return [true, true, true, true, true];
      case 6:
        return [false, true, true, true, true];
      case 7:
        return [false, false, true, true, true];
      case 8:
        return [false, false, false, true, true];
      case 9:
        return [false, false, false, false, true];
      default:
        throw new Error("输入只能是0-9数字");
    }
  }

  /**
   * 转换布尔数组：true → trueTo，false → falseTo
   * @param boolArray 原始布尔值数组
   * @param trueTo true转换为的整数值
   * @param falseTo false转换为的整数值
   * @returns 转换后的数字数组
   */
  private convertBoolArray(boolArray: boolean[], trueTo: number = 100, falseTo: number = 300): number[] {
    const result: number[] = [];
    boolArray.forEach((bool) => {
      result.push(bool ? trueTo : falseTo);
    });
    return result;
  }

  /**
   * 单次振动封装（返回Promise，支持await顺序执行）
   * @param duration 振动时长（毫秒）
   * @returns Promise<void> 振动完成/失败均resolve，避免中断序列
   */
  private singleVibrationPromise(duration: number): Promise<void> {
    return new Promise((resolve) => {
      // 若已标记终止，直接resolve
      if (this.isAbort) {
        resolve();
        return;
      }

      try {
        vibrator.startVibration(
          { type: 'time', duration },
          { id: 0, usage: 'alarm' },
          (error) => {
            if (error) {
              console.error(`单次振动失败: code=${error.code}, msg=${error.message}`);
              this.message = `振动${duration}ms失败`;
              resolve();
              return;
            }

            console.log(`开始振动${duration}ms`);
            this.message = `正在振动${duration}ms...`;

            // 振动时长到后停止，并resolve
            setTimeout(() => {
              if (this.isAbort) {
                resolve();
                return;
              }

              vibrator.stopVibration(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME, (stopErr) => {
                if (stopErr) {
                  console.error(`停止振动失败: code=${stopErr.code}, msg=${stopErr.message}`);
                }
                console.log(`${duration}ms振动已停止`);
                resolve(); // 振动完成，resolve Promise
              });
            }, duration);
          }
        );
      } catch (err) {
        console.error(`单次振动异常: code=${err.code}, msg=${err.message}`);
        this.message = `振动${duration}ms异常`;
        resolve();
      }
    });
  }

  /**
   * 等待固定时间（返回Promise，支持await）
   * @param ms 等待毫秒数
   * @returns Promise<void>
   */
  private wait(ms: number): Promise<void> {
    return new Promise((resolve) => {
      // 若已标记终止，直接resolve
      if (this.isAbort) {
        resolve();
        return;
      }

      console.log(`开始等待${ms}ms间隔...`);
      this.message = `等待${ms}ms间隔中...`;

      setTimeout(() => {
        resolve(); // 间隔结束，resolve Promise
      }, ms);
    });
  }

  /**
   * 数组序列振动（顺序执行版，基于async/await）
   * @param durations 振动时长数组
   * @param interval 两次振动间的固定间隔
   */
  private async executeArrayVibrationSequential(durations: number[], interval: number): Promise<void> {
    // 重置终止状态
    this.isAbort = false;

    // 顺序遍历数组，逐个执行「振动 + 间隔」
    for (let i = 0; i < durations.length; i++) {
      // 若已终止，直接退出循环
      if (this.isAbort) break;

      const currentDuration = durations[i];
      // 1. 执行当前振动（await等待完成）
      await this.singleVibrationPromise(currentDuration);

      // 2. 若不是最后一个元素，执行间隔等待（await等待完成）
      if (i < durations.length - 1 && !this.isAbort) {
        await this.wait(interval);
      }
    }

    // 序列执行完成/终止后提示
    if (!this.isAbort) {
      this.message = '振动序列执行完成';
    }
    // 重置终止状态
    this.isAbort = false;
  }

  /**
   * 终止所有振动和序列执行
   */
  private stopAllVibration(): void {
    // 标记终止，中断async/await序列
    this.isAbort = true;

    // 停止硬件振动
    try {
      vibrator.stopVibration(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME, (error) => {
        if (error) {
          console.error(`停止振动失败: code=${error.code}, msg=${error.message}`);
          return;
        }
        console.log('振动已强制停止');
      });
    } catch (err) {
      console.error(`停止振动异常: code=${err.code}, msg=${err.message}`);
    }
  }

  private async vibrateDigital(digital: number, messageCurrTime: string, messageDescribe: string, vibrateType: VibrateType): Promise<void> {
    if (!Number.isInteger(digital) || digital > 9 || digital < 0) {
      throw new Error("输入只能是0-9数字");
    }
    this.messageDetail = `当前时间：${messageCurrTime}， 正在振动 ${messageDescribe}: `;
    switch (vibrateType) {
      case VibrateType.Morse:
        await this.executeArrayVibrationSequential(
          this.convertBoolArray(this.digital2morse(digital), this.vibrationDot, this.vibrationDash),
          this.intervalTimeMorse
        );
        break
      case VibrateType.Direct:
        if (digital == 0) {
          await this.executeArrayVibrationSequential(
            [this.vibrationDash],
            this.intervalTimeDirect
          );
        } else {
          await this.executeArrayVibrationSequential(
            this.convertBoolArray(Array(digital).fill(true), this.vibrationDot, this.vibrationDash),
            this.intervalTimeDirect
          );
        }
        break
      default:
        throw new Error("非法的振动类型");
    }
    this.messageDetail = `当前时间：${messageCurrTime}， 等待2s `;
    await this.wait(this.intervalTimeDigit);
  }

  private async vibrateTime(vibrateType: VibrateType): Promise<void> {
    const [hour, minute, second] = this.getCurrTimeHMS()
    const currTime = `${this.fillTime(hour)}:${this.fillTime(minute)}:${this.fillTime(second)}`;

    this.stopAllVibration(); // 重置终止状态+停止振动
    //时 十位
    await this.vibrateDigital(Math.floor(hour / 10), currTime, '时 十位', vibrateType)
    await this.vibrateDigital(hour % 10, currTime, '时 个位', vibrateType)
    await this.vibrateDigital(Math.floor(minute / 10), currTime, '分 十位', vibrateType)
    await this.vibrateDigital(minute % 10, currTime, '分 个位', vibrateType)

    this.message = '振动报时完成'
    this.messageDetail = `当前时间：${currTime}， 振动报时完成 `;
  }
}