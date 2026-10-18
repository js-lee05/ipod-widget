import Testing
@testable import IPodCore

private func page(_ count: Int, kind: MenuPage.Kind = .songs) -> MenuPage {
    MenuPage(kind: kind, title: "T", items: (0..<count).map { MenuItem("\($0)", action: .none) })
}

@Test func moveScrollsToKeepSelectionVisible() {
    var nav = MenuNavigator(root: page(10), visibleRows: 3)
    nav.move(by: 4)
    #expect(nav.current.selection == 4)
    #expect(nav.current.top == 2)
    nav.move(by: -3)
    #expect(nav.current.selection == 1)
    #expect(nav.current.top == 1)
}

@Test func moveClampsAtBounds() {
    var nav = MenuNavigator(root: page(3), visibleRows: 6)
    nav.move(by: -5)
    #expect(nav.current.selection == 0)
    nav.move(by: 99)
    #expect(nav.current.selection == 2)
    #expect(nav.current.top == 0)
}

@Test func emptyPageHasNoSelection() {
    var nav = MenuNavigator(root: page(0), visibleRows: 6)
    nav.move(by: 1)
    #expect(nav.selectedItem == nil)
}

@Test func popAtRootFails() {
    var nav = MenuNavigator(root: page(2, kind: .root), visibleRows: 6)
    #expect(nav.pop() == false)
    nav.push(page(1))
    #expect(nav.pop() == true)
    #expect(nav.current.kind == .root)
}

@Test func updateItemsClampsSelection() {
    var nav = MenuNavigator(root: page(5, kind: .root), visibleRows: 2)
    nav.move(by: 4)
    nav.updateItems(of: .root, to: page(2).items)
    #expect(nav.current.selection == 1)
    #expect(nav.current.top == 0)
}
