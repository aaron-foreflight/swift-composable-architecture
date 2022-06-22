import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to show and hide views based on the presence of some optional child \
  state.

  The parent state holds a `CounterState?` value. When it is `nil` we will default to a plain text \
  view. But when it is non-`nil` we will show a view fragment for a counter that operates on the \
  non-optional counter state.

  Tapping "Toggle counter state" will flip between the `nil` and non-`nil` counter states.
  """

struct OptionalBasics: ReducerProtocol {
  struct State: Equatable {
    var optionalCounter: Counter.State?
  }

  enum Action: Equatable {
    case optionalCounter(Counter.Action)
    case toggleCounterButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .toggleCounterButtonTapped:
        state.optionalCounter =
          state.optionalCounter == nil
          ? Counter.State()
          : nil
        return .none
      case .optionalCounter:
        return .none
      }
    }
    .ifLet(state: \.optionalCounter, action: /Action.optionalCounter) {
      Counter()
    }
  }
}

struct OptionalBasicsView: View {
  let store: StoreOf<OptionalBasics>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {
          Button("Toggle counter state") {
            viewStore.send(.toggleCounterButtonTapped)
          }

          IfLetStore(
            self.store.scope(
              state: \.optionalCounter,
              action: OptionalBasics.Action.optionalCounter
            ),
            then: { store in
              VStack(alignment: .leading, spacing: 16) {
                Text(template: "`CounterState` is non-`nil`", .body)
                CounterView(store: store)
                  .buttonStyle(.borderless)
              }
            },
            else: {
              Text(template: "`CounterState` is `nil`", .body)
            }
          )
        }
      }
    }
    .navigationBarTitle("Optional state")
  }
}

struct OptionalBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        OptionalBasicsView(
          store: Store(
            initialState: OptionalBasics.State(),
            reducer: OptionalBasics()
          )
        )
      }

      NavigationView {
        OptionalBasicsView(
          store: Store(
            initialState: OptionalBasics.State(
              optionalCounter: Counter.State(count: 42)
            ),
            reducer: OptionalBasics()
          )
        )
      }
    }
  }
}
