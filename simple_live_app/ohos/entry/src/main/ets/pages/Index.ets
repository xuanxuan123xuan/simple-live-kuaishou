@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('Simple Live')
        .fontSize(20)
        .fontColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black)
  }
}