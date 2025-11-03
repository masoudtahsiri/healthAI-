import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var lastName: String = ""
    @State private var dateOfBirth: Date?
    @State private var gender: Gender = .male
    @State private var weight: Double = 70.0
    @State private var height: Double = 170.0
    @State private var selectedGoals: Set<FitnessGoal> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let profile = appState.userProfile {
                        Text("\(profile.firstName)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // Name section (firstName is read-only)
                if let profile = appState.userProfile {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // First Name - Read Only
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("First Name", text: .constant(profile.firstName))
                                .textFieldStyle(RoundedTextFieldStyle())
                                .disabled(true)
                                .opacity(0.6)
                        }
                        
                        // Last Name - Editable
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(RoundedTextFieldStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Date of Birth - Editable
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date of Birth")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    DatePicker(
                        "Date of Birth",
                        selection: Binding(
                            get: { dateOfBirth ?? Date().addingTimeInterval(-365.25 * 25 * 24 * 60 * 60) },
                            set: { dateOfBirth = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Gender - Editable
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gender")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { genderOption in
                            Text(genderOption.rawValue).tag(genderOption)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Height - Editable
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Height")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(height)) cm")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $height, in: 100...220, step: 1)
                        .tint(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Weight - Editable
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Weight")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(String(format: "%.1f", weight)) kg")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $weight, in: 30...200, step: 0.5)
                        .tint(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Fitness Goals - Editable
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fitness Goals")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Select one or more")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        ForEach(FitnessGoal.allCases, id: \.self) { goal in
                            Button(action: {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }) {
                                HStack {
                                    Text(goal.emoji)
                                        .font(.system(size: 24))
                                    Text(goal.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedGoals.contains(goal) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .font(.system(size: 20))
                                    }
                                }
                                .padding()
                                .background(selectedGoals.contains(goal) ? Color.blue.opacity(0.1) : Color(.systemGray5))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Save Button
                Button(action: saveProfile) {
                    Text("Save Changes")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedGoals.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(selectedGoals.isEmpty)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfileData()
        }
    }
    
    private func loadProfileData() {
        guard let profile = appState.userProfile else { return }
        
        lastName = profile.lastName
        dateOfBirth = profile.dateOfBirth
        gender = profile.gender
        weight = profile.weight
        height = profile.height
        selectedGoals = Set(profile.fitnessGoals)
    }
    
    private func saveProfile() {
        guard let profile = appState.userProfile else { return }
        
        // Create updated profile preserving createdAt
        var updatedProfile = UserProfile(
            firstName: profile.firstName, // Keep original firstName
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            weight: weight,
            height: height,
            fitnessGoals: Array(selectedGoals)
        )
        // Preserve the original createdAt date
        updatedProfile.createdAt = profile.createdAt
        
        appState.saveUserProfile(updatedProfile)
        dismiss()
    }
}

// MARK: - Custom TextField Style

fileprivate struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppState())
    }
}

