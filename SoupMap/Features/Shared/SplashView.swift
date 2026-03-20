import SwiftUI

struct SplashView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#65D1B6").opacity(0.22))
                        .frame(width: animate ? 168 : 136, height: animate ? 168 : 136)
                        .blur(radius: 18)

                    Circle()
                        .fill(Color(hex: "#65D1B6"))
                        .frame(width: 108, height: 108)

                    Circle()
                        .fill(Color(hex: "#FF8A73"))
                        .frame(width: 42, height: 42)
                        .offset(x: 0, y: -36)

                    Circle()
                        .fill(Color(hex: "#F8BA53"))
                        .frame(width: 28, height: 28)
                        .offset(x: 32, y: 28)
                }
                .scaleEffect(animate ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animate)

                VStack(spacing: 6) {
                    Text("SoupMap")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("A living Vancouver map for real-world momentum.")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(32)
        }
        .onAppear {
            animate = true
        }
    }
}
