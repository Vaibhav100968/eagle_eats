import SwiftUI

// MARK: - Reusable Input Components

struct GlassInputField: View {
    let label:        String
    let placeholder:  String
    @Binding var text: String
    let icon:         String
    var keyboardType: UIKeyboardType = .default
    var focused:      Bool           = false
    var errorMessage: String?        = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(errorMessage != nil ? Color.statusClosed
                                     : focused ? Color.untGreenPrimary : Color.textTertiary)
                    .animation(.easeInOut(duration: 0.2), value: focused)
                    .frame(width: 20)
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(errorMessage != nil ? Color.statusClosed.opacity(0.05)
                      : focused ? Color.untGreenBackground : Color(hex: "F9FAFB")))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(errorMessage != nil ? Color.statusClosed.opacity(0.5)
                              : focused ? Color.untGreenPrimary.opacity(0.6) : Color.borderSubtle,
                              lineWidth: errorMessage != nil || focused ? 1.5 : 1))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focused)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.statusClosed)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
    }
}

struct GlassPasswordField: View {
    let label:       String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var focused:  Bool    = false
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(errorMessage != nil ? Color.statusClosed
                                     : focused ? Color.untGreenPrimary : Color.textTertiary)
                    .animation(.easeInOut(duration: 0.2), value: focused)
                    .frame(width: 20)
                if showPassword {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text).font(.system(size: 16))
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showPassword.toggle() }
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(errorMessage != nil ? Color.statusClosed.opacity(0.05)
                      : focused ? Color.untGreenBackground : Color(hex: "F9FAFB")))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(errorMessage != nil ? Color.statusClosed.opacity(0.5)
                              : focused ? Color.untGreenPrimary.opacity(0.6) : Color.borderSubtle,
                              lineWidth: errorMessage != nil || focused ? 1.5 : 1))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focused)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.statusClosed)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
    }
}

// MARK: - Sign-In / Sign-Up View
//
// Provides local app-level authentication using email or phone number + password.
// Credentials are stored securely in Keychain via AuthService (HKDF-derived hash only).
// This is entirely separate from UNT portal authentication in MealPlanTab.

struct SignInView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss)  private var dismiss
    @FocusState private var focused: SignInField?

    @State private var identifier:    String = ""   // email or phone
    @State private var displayName:   String = ""
    @State private var password:      String = ""
    @State private var showPassword:  Bool   = false
    @State private var isSignUp:      Bool   = true   // default to sign-up for new users
    @State private var isLoading:     Bool   = false
    @State private var errorMessage:  String?
    @State private var fieldError:    [SignInField: String] = [:]

    @State private var elementsVisible = false
    @State private var heroVisible     = false

    enum SignInField: Hashable { case identifier, name, password }

    private var auth: AuthService { appState.auth }

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    formContent
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 60)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(10)
                            .background(Color.surfaceCard)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .padding(.trailing, 20).padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            // If an account already exists, default to sign-in mode
            if KeychainService.shared.load(.accountIdentifier) != nil {
                isSignUp = false
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) { elementsVisible = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25))  { heroVisible = true }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack {
            LinearGradient.untHeroGradient
            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 44, weight: .semibold)).foregroundStyle(.white)
                Text("Eagle Eats")
                    .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                    .animation(.easeInOut(duration: 0.2), value: isSignUp)
            }
            .offset(y: heroVisible ? 0 : 20)
            .opacity(heroVisible ? 1 : 0)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 20).padding(.top, 60)
        .shadow(color: Color.untGreenDark.opacity(0.25), radius: 22, x: 0, y: 10)
    }

    // MARK: - Form

    @ViewBuilder
    private var formContent: some View {
        // Title + description
        stagger(delay: 0.1) {
            VStack(alignment: .leading, spacing: 5) {
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text(isSignUp
                     ? "Use your email or phone number. Your credentials are stored only on this device."
                     : "Sign in with your email or phone number.")
                .font(.system(size: 14)).foregroundStyle(Color.textSecondary).lineSpacing(2)
            }
        }
        .padding(.bottom, 24)

        VStack(spacing: 14) {
            // Display name (sign-up only)
            if isSignUp {
                stagger(delay: 0.12) {
                    GlassInputField(
                        label: "Display Name (optional)",
                        placeholder: "Your first name",
                        text: $displayName,
                        icon: "person.fill",
                        focused: focused == .name
                    )
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .identifier }
                }
                .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity),
                                        removal: .push(from: .bottom).combined(with: .opacity)))
            }

            // Email / phone
            stagger(delay: 0.18) {
                GlassInputField(
                    label: "Email or Phone Number",
                    placeholder: "yourname@unt.edu or 9725551234",
                    text: $identifier,
                    icon: identifier.contains("@") ? "envelope.fill" : "phone.fill",
                    keyboardType: .emailAddress,
                    focused: focused == .identifier,
                    errorMessage: fieldError[.identifier]
                )
                .focused($focused, equals: .identifier)
                .submitLabel(.next)
                .onSubmit { focused = .password }
            }

            // Password
            stagger(delay: 0.24) {
                GlassPasswordField(
                    label: "Password",
                    placeholder: isSignUp ? "At least 8 characters" : "Enter your password",
                    text: $password,
                    showPassword: $showPassword,
                    focused: focused == .password,
                    errorMessage: fieldError[.password]
                )
                .focused($focused, equals: .password)
                .submitLabel(.done)
                .onSubmit { Task { await submit() } }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSignUp)

        // Global error banner
        if let err = errorMessage {
            stagger(delay: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.statusClosed)
                    Text(err)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.statusClosed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.statusClosed.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }

        // Primary action button
        stagger(delay: 0.3) {
            Button {
                Task { await submit() }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LinearGradient(colors: [.untGreenMedium, .untGreenDark],
                                           startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.untGreenDark.opacity(0.35), radius: 12, x: 0, y: 6)
                .opacity(isLoading ? 0.8 : 1)
            }
            .buttonStyle(SpringButtonStyle())
            .disabled(isLoading)
            .padding(.top, 10)
        }

        // Toggle sign-in / sign-up
        stagger(delay: 0.42) {
            HStack(spacing: 4) {
                Text(isSignUp ? "Already have an account?" : "New to Eagle Eats?")
                    .font(.system(size: 14)).foregroundStyle(Color.textSecondary)
                Button(isSignUp ? "Sign In" : "Create Account") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        isSignUp.toggle()
                        clearErrors()
                    }
                }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.untGreenPrimary)
            }
            .frame(maxWidth: .infinity).padding(.top, 8)
        }
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        focused = nil
        clearErrors()

        guard !identifier.trimmingCharacters(in: .whitespaces).isEmpty else {
            fieldError[.identifier] = "Email or phone is required."
            return
        }
        guard !password.isEmpty else {
            fieldError[.password] = "Password is required."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUp {
                try auth.signUp(
                    identifier: identifier.trimmingCharacters(in: .whitespaces),
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } else {
                try auth.signIn(
                    identifier: identifier.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            appState.didSignIn()
            dismiss()
        } catch let e as AuthError {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                switch e {
                case .invalidIdentifier:
                    fieldError[.identifier] = e.localizedDescription
                case .passwordTooShort:
                    fieldError[.password] = e.localizedDescription
                case .wrongPassword:
                    fieldError[.password] = e.localizedDescription
                case .accountNotFound:
                    // Auto-switch to sign-up and prompt user
                    isSignUp = true
                    errorMessage = "No account found — create one below."
                case .accountExists:
                    // Auto-switch to sign-in since account already exists
                    isSignUp = false
                    errorMessage = "Account already exists — sign in instead."
                case .keychainFailure:
                    errorMessage = "Could not access secure storage. Try restarting the app."
                }
            }
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearErrors() {
        errorMessage = nil
        fieldError.removeAll()
    }

    // MARK: - Stagger helper

    @ViewBuilder
    private func stagger<V: View>(delay: Double, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .opacity(elementsVisible ? 1 : 0)
            .offset(y: elementsVisible ? 0 : 14)
            .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(delay), value: elementsVisible)
    }
}
