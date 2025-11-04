import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState 
    @State private var currentStep = 0
    @State private var isLoadingHealthKitData = false
    
    // Personal info (from HealthKit or manual entry)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth: Date?
    @State private var gender: Gender = .male
    
    // Physical stats
    @State private var weight: Double = 70.0
    @State private var height: Double = 170.0
    
    // Fitness goals (multi-select)
    @State private var selectedGoals: Set<FitnessGoal> = []
    
    var body: some View {
        ZStack {
            // Fixed gradient background matching splash screen style
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.3, blue: 0.6),      // Deep athletic blue
                    Color(red: 0.0, green: 0.5, blue: 0.8),      // Vibrant ocean blue
                    Color(red: 0.2, green: 0.7, blue: 0.9),      // Bright cyan/teal
                    Color(red: 0.4, green: 0.8, blue: 1.0)       // Electric cyan
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle static background circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: -50, y: -100)
            
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 50, y: 100)
            
            if currentStep == 0 {
                welcomeView
            } else if currentStep == 1 {
                nameEntryView
            } else if currentStep == 2 {
                syncingHealthDataView
            } else if currentStep == 3 {
                goalSelectionView
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo icon matching splash screen
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 140, height: 140)
                
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.white.opacity(0.5), radius: 20, x: 0, y: 0)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to HealthAI+")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Track your health journey with AI-powered insights")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text("Powered by Apple Intelligence™")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 8)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    currentStep = 1
                }
            }) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
    
    private var nameEntryView: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("First Name")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    TextField("Enter your first name", text: $firstName)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Last Name")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    TextField("Enter your last name", text: $lastName)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                Button(action: {
                    // Start syncing HealthKit data when continuing
                    Task {
                        let startTime = Date()
                        
                        await MainActor.run {
                            isLoadingHealthKitData = true
                            withAnimation {
                                currentStep = 2
                            }
                        }
                        
                        // Request authorization and fetch data
                        _ = await appState.healthKitManager.requestAuthorization()
                        await loadHealthKitData()
                        
                        // Ensure minimum 5 second loading
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed < 5.0 {
                            let remaining = 5.0 - elapsed
                            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                        }
                        
                        await MainActor.run {
                            isLoadingHealthKitData = false
                        }
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor((firstName.isEmpty && lastName.isEmpty) ? .white.opacity(0.5) : .white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        (firstName.isEmpty && lastName.isEmpty)
                            ? Color.white.opacity(0.15)
                            : Color.white.opacity(0.25)
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(firstName.isEmpty && lastName.isEmpty)
                
                Button(action: {
                    withAnimation { currentStep = 0 }
                }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
        }
    }
    
    private var syncingHealthDataView: some View {
        VStack(spacing: 30) {
            if isLoadingHealthKitData {
                loadingHealthDataView
            } else {
                syncedDataView
            }
        }
    }
    
    private var loadingHealthDataView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2.0)
            
            Text("Syncing with Health App")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Fetching your health data...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 8)
        }
        .padding(.vertical, 60)
    }
    
    private var syncedDataView: some View {
        VStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 15) {
                dateOfBirthCard
                genderCard
                heightCard
                weightCard
            }
            .padding(.horizontal, 40)
            
            actionButtons
        }
    }
    
    private var dateOfBirthCard: some View {
        let isFilled = dateOfBirth != nil
        let backgroundColor = isFilled ? Color.white.opacity(0.3) : Color.white.opacity(0.25)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
                Text("Date of Birth:")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                if isFilled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                }
            }
            
            DatePicker(
                "Date of Birth",
                selection: Binding(
                    get: { dateOfBirth ?? Date().addingTimeInterval(-365.25 * 25 * 24 * 60 * 60) },
                    set: { dateOfBirth = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .accentColor(.white)
            .colorScheme(.dark)
            .labelsHidden()
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
    
    private var genderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
                Text("Gender:")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 22))
            }
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases, id: \.self) { genderOption in
                    Text(genderOption.rawValue).tag(genderOption)
                        .foregroundColor(.white)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(.white)
        }
        .padding(16)
        .background(Color.white.opacity(0.3))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
    
    private var heightCard: some View {
        let isCustomized = height != 170.0
        let backgroundColor = isCustomized ? Color.white.opacity(0.3) : Color.white.opacity(0.25)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
                Text("Height:")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(Int(height)) cm")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .font(.system(size: 19))
                if isCustomized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                }
            }
            
            Slider(value: $height, in: 100...220, step: 1)
                .tint(.white)
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
    
    private var weightCard: some View {
        let isCustomized = weight != 70.0
        let backgroundColor = isCustomized ? Color.white.opacity(0.3) : Color.white.opacity(0.25)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
                Text("Weight:")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(Int(weight)) kg")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .font(.system(size: 19))
                if isCustomized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                }
            }
            
            Slider(value: $weight, in: 30...200, step: 0.5)
                .tint(.white)
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation { currentStep = 3 }
            }) {
                HStack {
                    Spacer()
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.25))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            
            Button(action: {
                withAnimation { currentStep = 1 }
            }) {
                Text("Back")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }
    
    private var goalSelectionView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header section with better spacing
                VStack(spacing: 12) {
                    Text("What's your goal?")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Select one or more fitness goals")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.bottom, 32)
                .padding(.horizontal, 32)
                
                // Goals grid with improved spacing and padding
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16,
                    content: {
                        ForEach(FitnessGoal.allCases, id: \.self) { goal in
                            GoalSelectionButton(
                                goal: goal,
                                isSelected: selectedGoals.contains(goal),
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedGoals.contains(goal) {
                                            selectedGoals.remove(goal)
                                        } else {
                                            selectedGoals.insert(goal)
                                        }
                                    }
                                }
                            )
                        }
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Action buttons with improved spacing
                VStack(spacing: 16) {
                    Button(action: {
                        completeOnboarding()
                    }) {
                        HStack {
                            Spacer()
                            Text("Finish")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedGoals.isEmpty ? .white.opacity(0.5) : .white)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(
                            selectedGoals.isEmpty 
                                ? Color.white.opacity(0.15)
                                : Color.white.opacity(0.25)
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(selectedGoals.isEmpty)
                    .padding(.horizontal, 32)
                    
                    Button(action: {
                        withAnimation { currentStep = 2 }
                    }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Goal Selection Button Component
struct GoalSelectionButton: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(goal.emoji)
                        .font(.system(size: 36))
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                        .font(.system(size: 20, weight: .medium))
                }
                
                Text(goal.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                Group {
                    if isSelected {
                        Color.white.opacity(0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            )
                    } else {
                        Color.white.opacity(0.18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            )
            .cornerRadius(16)
            .shadow(color: isSelected ? Color.white.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension OnboardingView {
    private func loadHealthKitData() async {
        // Note: isLoadingHealthKitData is managed by the calling function
        
        // Request authorization first
        _ = await appState.healthKitManager.requestAuthorization()
        
        // Fetch profile data
        let healthData = await appState.healthKitManager.readUserProfileData()
        
        await MainActor.run {
            // Update firstName if available
            if let firstNameFromHealth = healthData.firstName, !firstNameFromHealth.isEmpty {
                firstName = firstNameFromHealth
            }
            
            // Update lastName if available
            if let lastNameFromHealth = healthData.lastName, !lastNameFromHealth.isEmpty {
                lastName = lastNameFromHealth
            }
            
            // Update date of birth
            if let dob = healthData.dateOfBirth {
                dateOfBirth = dob
            }
            
            // Update gender
            if let genderFromHealth = healthData.gender {
                gender = genderFromHealth
            }
            
            // Update height (from HealthKit if available)
            if let heightFromHealth = healthData.height, heightFromHealth > 0 {
                height = heightFromHealth
            }
            
            // Update weight (from HealthKit if available)
            if let weightFromHealth = healthData.weight, weightFromHealth > 0 {
                weight = weightFromHealth
            }
        }
    }
    
    private func completeOnboarding() {
        let profile = UserProfile(
            firstName: firstName.isEmpty ? "User" : firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            weight: weight,
            height: height,
            fitnessGoals: Array(selectedGoals)
        )
        appState.saveUserProfile(profile)
    }
}

// MARK: - Custom Styles

fileprivate struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.2))
            .cornerRadius(14)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(configuration.isPressed ? 0.4 : 0.3))
            .cornerRadius(15)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.15))
            .cornerRadius(15)
    }
}
