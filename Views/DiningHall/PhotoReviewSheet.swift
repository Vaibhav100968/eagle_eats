import SwiftUI
import PhotosUI

// MARK: - Add Photo Review Sheet

struct AddPhotoReviewSheet: View {
    let menuItemName: String
    let recipeId: String
    let hallId: String
    let hallName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var reviewService = PhotoReviewService.shared

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var rating: Int = 4
    @State private var comment: String = ""
    @State private var showCamera = false
    @State private var saving = false
    @State private var filterError: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Photo section
                    photoSection

                    // Rating
                    ratingSection

                    // Comment
                    commentSection

                    // Submit
                    if selectedImage != nil {
                        submitButton
                    }
                }
                .padding(20)
            }
            .background(Color.untGreenBackground.ignoresSafeArea())
            .navigationTitle("Review \(menuItemName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    selectedImage = nil
                    selectedPhotoItem = nil
                } label: {
                    Text("Remove Photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.statusClosed)
                }
            } else {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28, weight: .medium))
                            Text("Photo Library")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .background(Color.surfaceBase)
                        .foregroundStyle(Color.untGreenPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    Button {
                        showCamera = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .medium))
                            Text("Take Photo")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .background(Color.surfaceBase)
                        .foregroundStyle(Color.untGreenPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How was it?")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            rating = star
                        }
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(star <= rating ? Color(hex: "F59E0B") : Color.textTertiary.opacity(0.3))
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(ratingLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Terrible"
        case 2: return "Meh"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Amazing!"
        default: return ""
        }
    }

    // MARK: - Comment Section

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a comment (optional)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            TextField("How did it taste? Any notes?", text: $comment, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3...6)
                .padding(14)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let filterError {
                Text(filterError)
                    .font(.caption)
                    .foregroundStyle(Color.statusClosed)
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            guard let image = selectedImage else { return }
            let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !ContentFilter.isAcceptable(trimmed) {
                filterError = "Please remove inappropriate language before posting."
                return
            }
            filterError = nil
            saving = true
            reviewService.addReview(
                menuItemName: menuItemName,
                recipeId: recipeId,
                hallId: hallId,
                hallName: hallName,
                rating: rating,
                comment: comment,
                image: image
            )
            HapticService.shared.success()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                if saving {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(saving ? "Saving..." : "Post Review")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.untGreenDark.opacity(0.4), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(SpringButtonStyle())
        .disabled(saving)
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Review Gallery (shows reviews for a menu item)

struct PhotoReviewGallery: View {
    let recipeId: String
    let menuItemName: String
    let hallId: String
    let hallName: String

    @StateObject private var reviewService = PhotoReviewService.shared
    @State private var showAddReview = false

    private var itemReviews: [PhotoReview] { reviewService.reviews(for: recipeId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photo Reviews")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button {
                    showAddReview = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11))
                        Text("Add")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.untGreenPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.untGreenPrimary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if itemReviews.isEmpty {
                Text("No photos yet. Be the first to review!")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(itemReviews) { review in
                            PhotoReviewCard(review: review)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddReview) {
            AddPhotoReviewSheet(
                menuItemName: menuItemName,
                recipeId: recipeId,
                hallId: hallId,
                hallName: hallName
            )
        }
    }
}

// MARK: - Photo Review Card

private struct PhotoReviewCard: View {
    let review: PhotoReview
    @StateObject private var reviewService = PhotoReviewService.shared
    @State private var showReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = reviewService.loadPhoto(for: review) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.system(size: 8))
                        .foregroundStyle(star <= review.rating ? Color(hex: "F59E0B") : Color.textTertiary.opacity(0.3))
                }
                Spacer()
                Text(review.timeAgo)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textTertiary)
            }

            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 140)
        .contextMenu {
            Button(role: .destructive) {
                showReport = true
            } label: {
                Label("Report Review", systemImage: "flag.fill")
            }
        }
        .sheet(isPresented: $showReport) {
            ReportContentSheet(
                contentType: .photoReview,
                contentId: review.id
            )
        }
    }
}
