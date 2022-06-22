import ComposableArchitecture
import XCTest

@testable import Todos

@MainActor
class TodosTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testAddTodo() {
    let store = TestStore(
      initialState: AppReducer.State(),
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.addTodoButtonTapped) {
      $0.todos.insert(
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        at: 0
      )
    }
  }

  func testEditTodo() {
    let state = AppReducer.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        )
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(
      .todo(id: state.todos[0].id, action: .textFieldChanged("Learn Composable Architecture"))
    ) {
      $0.todos[id: state.todos[0].id]?.description = "Learn Composable Architecture"
    }
  }

  func testCompleteTodo() async {
    let state = AppReducer.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.mainQueue.advance(by: 1)
    await store.receive(.sortCompletedTodos) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
      ]
    }
  }

  func testCompleteTodoDebounces() async {
    let state = AppReducer.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = true
    }
    await self.mainQueue.advance(by: 0.5)
    store.send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
      $0.todos[id: state.todos[0].id]?.isComplete = false
    }
    await self.mainQueue.advance(by: 1)
    await store.receive(.sortCompletedTodos)
  }

  func testClearCompleted() {
    let store = TestStore(
      initialState: AppReducer.State(
        todos: [
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: true
          ),
        ]
      ),
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.clearCompletedButtonTapped) {
      $0.todos = [
        $0.todos[0]
      ]
    }
  }

  func testDelete() {
    let store = TestStore(
      initialState: AppReducer.State(
        todos: [
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            isComplete: false
          ),
        ]
      ),
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.delete([1])) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
      ]
    }
  }

  func testEditModeMoving() async {
    let store = TestStore(
      initialState: AppReducer.State(
        todos: [
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            isComplete: false
          ),
        ]
      ),
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    store.send(.move([0], 2)) {
      $0.todos = [
        $0.todos[1],
        $0.todos[0],
        $0.todos[2],
      ]
    }
    await self.mainQueue.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testEditModeMovingWithFilter() async {
    let store = TestStore(
      initialState: AppReducer.State(
        todos: [
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: true
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            isComplete: false
          ),
          Todo.State(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            isComplete: true
          ),
        ]
      ),
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.editModeChanged(.active)) {
      $0.editMode = .active
    }
    store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    store.send(.move([0], 1)) {
      $0.todos = [
        $0.todos[0],
        $0.todos[2],
        $0.todos[1],
        $0.todos[3],
      ]
    }
    await self.mainQueue.advance(by: .milliseconds(100))
    await store.receive(.sortCompletedTodos)
  }

  func testFilteredEdit() {
    let state = AppReducer.State(
      todos: [
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo.State(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: AppReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.uuid, .incrementing)
    )

    store.send(.filterPicked(.completed)) {
      $0.filter = .completed
    }
    store.send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
      $0.todos[id: state.todos[1].id]?.description = "Did this already"
    }
  }
}

extension UUID {
  // A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }
}
