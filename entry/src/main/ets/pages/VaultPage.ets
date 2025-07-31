import router from '@ohos.router';

@Entry
@Component
struct VaultPage {
  @State isLoading: boolean = false;
  @State searchText: string = '';
  @State ciphers: any[] = [];

  aboutToAppear() {
    this.loadCiphers();
  }

  private async loadCiphers() {
    this.isLoading = true;
    // 模拟加载数据
    setTimeout(() => {
      this.ciphers = [
        { id: '1', name: 'GitHub', type: 1, username: 'user@example.com', favorite: true },
        { id: '2', name: 'Google', type: 1, username: 'user@gmail.com', favorite: false },
        { id: '3', name: '银行卡', type: 3, cardNumber: '**** **** **** 1234', favorite: false }
      ];
      this.isLoading = false;
    }, 1000);
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('密码库')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        
        Blank()
        
        Button() {
          Text('设置')
            .fontSize(16)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // 搜索栏
      Row() {
        TextInput({ 
          placeholder: '搜索密码项...',
          text: this.searchText 
        })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      // 密码项列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.ciphers.length === 0) {
        Column() {
          Text('暂无密码项')
            .fontSize(16)
            .fontColor(Color.Gray)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.ciphers, (cipher: any) => {
            ListItem() {
              Row() {
                Column() {
                  Text(cipher.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  
                  Text(cipher.username || cipher.cardNumber || '')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button() {
                  Text(cipher.favorite ? '★' : '☆')
                    .fontSize(20)
                }
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  cipher.favorite = !cipher.favorite;
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .margin({ bottom: 8 })
              .onClick(() => {
                this.navigateToDetail(cipher);
              })
            }
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
      }

      // 悬浮添加按钮
      Button() {
        Text('+')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor('#007AFF')
      .borderRadius(28)
      .position({ x: '85%', y: '85%' })
      .onClick(() => {
        this.navigateToAdd();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private navigateToDetail(cipher: any) {
    router.pushUrl({ 
      url: 'pages/CipherDetailPage',
      params: { cipherId: cipher.id }
    });
  }

  private navigateToAdd() {
    router.pushUrl({ url: 'pages/AddCipherPage' });
  }
} 