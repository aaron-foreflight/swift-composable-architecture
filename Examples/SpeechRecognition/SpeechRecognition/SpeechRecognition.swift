import Combine
import ComposableArchitecture
import Speech
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a complex dependency in the Composable \
  Architecture. It uses the SFSpeechRecognizer API from the Speech framework to listen to audio on \
  the device and live-transcribe it to the UI.
  """

struct AppState: Equatable {
  var alert: AlertState<AppAction>?
  var isRecording = false
  var speechRecognizerAuthorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
  var transcribedText = ""
}

enum AppAction: Equatable {
  case dismissAuthorizationStateAlert
  case recordButtonTapped
  case speech(TaskResult<SpeechClient.Action>)
  case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
}

struct AppEnvironment {
  var speechClient: SpeechClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  enum CancelId {}

  switch action {
  case .dismissAuthorizationStateAlert:
    state.alert = nil
    return .none

  case .recordButtonTapped:
    state.isRecording.toggle()
    if state.isRecording {
      return .run { @MainActor [isRecording = state.isRecording] send in
        send(
          .speechRecognizerAuthorizationStatusResponse(
            await environment.speechClient.requestAuthorization()
          )
        )
      }
      .cancellable(id: CancelId.self)
    } else {
      return .cancel(id: CancelId.self)
    }

  case let .speech(.success(.availabilityDidChange(isAvailable))):
    return .none

  case let .speech(.success(.taskResult(result))):
    state.transcribedText = result.bestTranscription.formattedString
    return result.isFinal ? .none : .cancel(id: CancelId.self)

  case .speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession)),
    .speech(.failure(SpeechClient.Failure.couldntStartAudioEngine)):
    state.alert = .init(title: .init("Problem with audio device. Please try again."))
    return .none

  case let .speech(.failure(error)):
    state.alert = .init(title: .init("An error occurred while transcribing. Please try again."))
    return .cancel(id: CancelId.self)

  case let .speechRecognizerAuthorizationStatusResponse(status):
    state.isRecording = status == .authorized
    state.speechRecognizerAuthorizationStatus = status

    switch status {
    case .notDetermined:
      state.alert = .init(title: .init("Try again."))
      return .none

    case .denied:
      state.alert = .init(
        title: .init(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      return .none

    case .restricted:
      state.alert = .init(title: .init("Your device does not allow speech recognition."))
      return .none

    case .authorized:
      return .run { @MainActor send in
        do {
          let request = SFSpeechAudioBufferRecognitionRequest()
          request.shouldReportPartialResults = true
          request.requiresOnDeviceRecognition = false
          for try await action in await environment.speechClient.recognitionTask(request) {
            send(.speech(.success(action)))
          }
        } catch {
          send(.speech(.failure(error)))
        }
      }

    @unknown default:
      return .none
    }
  }
}
.debug(actionFormat: .labelsOnly)

struct AuthorizationStateAlert: Equatable, Identifiable {
  var title: String

  var id: String { self.title }
}

struct SpeechRecognitionView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding(.bottom, 32)

          Text(viewStore.transcribedText)
            .font(.largeTitle)
            .minimumScaleFactor(0.1)
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        }

        Spacer()

        Button(action: { viewStore.send(.recordButtonTapped) }) {
          HStack {
            Image(
              systemName: viewStore.isRecording
                ? "stop.circle.fill" : "arrowtriangle.right.circle.fill"
            )
            .font(.title)
            Text(viewStore.isRecording ? "Stop Recording" : "Start Recording")
          }
          .foregroundColor(.white)
          .padding()
          .background(viewStore.isRecording ? Color.red : .green)
          .cornerRadius(16)
        }
      }
      .padding()
      .alert(self.store.scope(state: \.alert), dismiss: .dismissAuthorizationStateAlert)
    }
  }
}

struct SpeechRecognitionView_Previews: PreviewProvider {
  static var previews: some View {
    SpeechRecognitionView(
      store: Store(
        initialState: .init(transcribedText: "Test test 123"),
        reducer: appReducer,
        environment: AppEnvironment(
          speechClient: .live
        )
      )
    )
  }
}
