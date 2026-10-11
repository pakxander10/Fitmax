import SwiftUI

/// Sign in or create an account: the first screen of a fresh install.
struct AuthScreen: View {
    private enum Field { case name, email, password }

    @Environment(AppModel.self) private var model
    @Environment(\.flatScroll) private var flat

    @State private var mode: AuthMode
    @State private var credentials = Credentials()
    @State private var problem: String?
    @State private var working = false
    @FocusState private var focus: Field?

    /// `mode` picks which tab opens first, for previews and render tests.
    init(mode: AuthMode = .signIn) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        if flat {
            content
        } else {
            ScrollView { content }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            BrandHeader()
            form
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            modeSwitch

            if mode == .signUp {
                FQField(label: "Name", focused: focus == .name) {
                    TextField("", text: $credentials.name, prompt: prompt("Alex Moreno"))
                        .nameEntry()
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = .email }
                }
            }
            FQField(label: "Email", focused: focus == .email) {
                TextField("", text: $credentials.email, prompt: prompt("you@example.com"))
                    .emailEntry()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
            }
            VStack(alignment: .leading, spacing: 6) {
                FQField(label: "Password", focused: focus == .password) {
                    SecureField("", text: $credentials.password)
                        .passwordEntry(new: mode == .signUp)
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .onSubmit(submit)
                }
                if mode == .signUp {
                    Text("At least \(Credentials.minPasswordLength) characters.").caption()
                }
            }

            if let problem {
                Label(problem, systemImage: "exclamationmark.circle.fill")
                    .font(Theme.caption(14))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FQButton(title: buttonTitle, wide: true, action: submit)
                .disabled(working)

            if model.usesLocalAccounts {
                Text("Accounts are saved on this phone only for now.").caption()
            }
        }
        .aeroCard()
        .onChange(of: credentials) { problem = nil }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            option("Sign in", .signIn)
            option("Create account", .signUp)
        }
        .padding(3)
        .background(Capsule().fill(Theme.well))
        .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.5), lineWidth: 1))
    }

    private func option(_ title: String, _ option: AuthMode) -> some View {
        let selected = mode == option
        return Button {
            mode = option
            problem = nil
        } label: {
            Text(title)
                .heading(15, color: selected ? .white : Theme.link)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background { if selected { Glossy(shape: Capsule(), fill: Theme.blueGloss) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(working)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var buttonTitle: String {
        switch mode {
        case .signIn: working ? "Signing in…" : "Sign in"
        case .signUp: working ? "Creating account…" : "Create account"
        }
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Theme.muted.opacity(0.7))
    }

    private func submit() {
        guard !working else { return }
        if let issue = credentials.problem(for: mode) {
            problem = issue
            return
        }
        problem = nil
        working = true
        focus = nil
        Task {
            do {
                switch mode {
                case .signIn: try await model.signIn(email: credentials.email, password: credentials.password)
                case .signUp: try await model.signUp(name: credentials.name, email: credentials.email, password: credentials.password)
                }
            } catch let error as AuthError {
                problem = error.message
            } catch {
                // The sign-in itself worked; loading the profile did not.
                problem = "Couldn’t load your profile. Check your connection and try again."
            }
            working = false
        }
    }
}

/// The app's name and mascot, on the open sky.
struct BrandHeader: View {
    var body: some View {
        VStack(spacing: 6) {
            DogView(walking: false)
                .frame(width: DogView.size.width, height: DogView.size.height)
                .scaleEffect(1.25)
                .frame(height: DogView.size.height * 1.25)
                .accessibilityHidden(true)
            Text("FitQuest").heading(40, color: Theme.onSky).accessibilityAddTraits(.isHeader)
            Text("Eat well, train, and raise your pet.").copy(16, color: Theme.onSky.opacity(0.95))
        }
        .skyShadow()
    }
}

/// Shown while a remembered account's profile loads, with a way out if it will not.
struct LaunchScreen: View {
    @Environment(AppModel.self) private var model

    @State private var retrying = false

    var body: some View {
        VStack(spacing: 24) {
            BrandHeader()
            if model.restoreFailed {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Couldn’t load your profile").heading(18)
                    Text("Check your connection and try again.").copy(15)
                    HStack(spacing: 12) {
                        FQButton(title: retrying ? "Trying…" : "Try again") {
                            retrying = true
                            Task {
                                await model.restoreSession()
                                retrying = false
                            }
                        }
                        .disabled(retrying)
                        FQButton(title: "Sign out", variant: .secondary, action: model.signOut)
                    }
                }
                .aeroCard()
            } else {
                ProgressView().tint(.white).accessibilityLabel("Loading your profile")
            }
        }
        // Same place as on the login screen, so the mascot does not jump when one replaces the other.
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
