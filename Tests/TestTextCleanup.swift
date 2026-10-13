import Foundation

/// TextCleanup 是纯函数，分「应保留换行」和「应合并」两类分支覆盖。
/// 另外用 characterization 断言把两个已知取舍钉住：行为一旦变化就会失败，
/// 提醒改动者是有意改进还是误伤。
func testTextCleanup() {
    // ——— 应保留换行 ———
    eq(
        TextCleanup.mergeParagraphs("第一句结束。\n第二句开始。"),
        "第一句结束。\n第二句开始。", "句末标点后保留换行")

    eq(
        TextCleanup.mergeParagraphs("标题\n- 第一项\n- 第二项"),
        "标题\n- 第一项\n- 第二项", "无序列表保留换行")

    eq(
        TextCleanup.mergeParagraphs("步骤：\n1. 第一步\n2. 第二步"),
        "步骤：\n1. 第一步\n2. 第二步", "有序列表保留换行")

    eq(
        TextCleanup.mergeParagraphs("第一段\n\n第二段"),
        "第一段\n\n第二段", "空行分段保留")

    eq(
        TextCleanup.mergeParagraphs("单行文本没有换行"),
        "单行文本没有换行", "单行原样返回")

    // ——— 应合并 ———
    eq(
        TextCleanup.mergeParagraphs(
            "This is a long sentence that got\nwrapped by OCR into lines\nand continues here."),
        "This is a long sentence that got wrapped by OCR into lines and continues here.",
        "英文视觉断行接回，补空格")

    eq(
        TextCleanup.mergeParagraphs("这是一段被 OCR 按视觉行\n切断的中文"),
        "这是一段被 OCR 按视觉行切断的中文", "中文视觉断行接回，不补空格")

    eq(
        TextCleanup.mergeParagraphs("使用 Swift\n编写代码"),
        "使用 Swift 编写代码", "中英边界补空格")

    // ——— 已知取舍（characterization）———
    // 见 README「合并段落」一节：刻意只处理明显同段的情况，宁可少合并。
    // 下面两条记录的是当前真实行为，不是期望行为；若将来改进，这两条应当被有意更新。
    eq(
        TextCleanup.mergeParagraphs("func foo() {\n    let x = 1\n}"),
        "func foo() { let x = 1 }", "[已知取舍] 代码块会被揉成一行")

    eq(
        TextCleanup.mergeParagraphs("- 一级项\n  - 二级项"),
        "- 一级项\n- 二级项", "[已知取舍] 嵌套列表缩进被吃掉")
}
