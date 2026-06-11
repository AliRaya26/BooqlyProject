"""Generate Booqly presentation guide PDF for academic presentation."""

from fpdf import FPDF
from datetime import date

OUTPUT = r"c:\Users\user\Desktop\app project\book\BooqlyProject\docs\Booqly_Presentation_Guide.pdf"


class PresentationPDF(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(120, 120, 120)
            self.cell(0, 8, "Booqly - Presentation Guide", align="L")
            self.ln(4)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def cover(self):
        self.add_page()
        self.set_fill_color(79, 70, 229)
        self.rect(0, 0, 210, 70, "F")
        self.set_y(22)
        self.set_font("Helvetica", "B", 32)
        self.set_text_color(255, 255, 255)
        self.cell(0, 14, "Booqly", ln=True, align="C")
        self.set_font("Helvetica", "", 14)
        self.cell(0, 8, "Cross-Platform Reading Companion App", ln=True, align="C")
        self.ln(30)
        self.set_text_color(30, 30, 30)
        self.set_font("Helvetica", "B", 16)
        self.cell(0, 10, "Presentation Guide for Your Professor", ln=True, align="C")
        self.ln(6)
        self.set_font("Helvetica", "", 11)
        self.set_text_color(80, 80, 80)
        self.multi_cell(
            0,
            6,
            "Everything you need to explain the project: purpose, features, "
            "architecture, technologies, demo flow, and likely questions.",
            align="C",
        )
        self.ln(20)
        self.set_font("Helvetica", "", 10)
        self.cell(0, 6, f"Generated: {date.today().strftime('%B %d, %Y')}", ln=True, align="C")
        self.cell(0, 6, "Repository: github.com/AliRaya26/BooqlyProject", ln=True, align="C")
        self.cell(0, 6, "Firebase Project: booqlyapp-83777", ln=True, align="C")

    def section_title(self, title):
        self.ln(4)
        self.set_font("Helvetica", "B", 14)
        self.set_text_color(79, 70, 229)
        self.cell(0, 10, title, ln=True)
        self.set_draw_color(79, 70, 229)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def sub_title(self, title):
        self.ln(2)
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(40, 40, 40)
        self.cell(0, 8, title, ln=True)

    def body(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(50, 50, 50)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def bullet(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(50, 50, 50)
        x = self.get_x()
        self.cell(6, 5.5, chr(149))
        self.multi_cell(0, 5.5, text)
        self.set_x(x)

    def numbered(self, n, text):
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(79, 70, 229)
        self.cell(8, 5.5, f"{n}.")
        self.set_font("Helvetica", "", 10)
        self.set_text_color(50, 50, 50)
        self.multi_cell(0, 5.5, text)
        self.ln(1)


def build():
    pdf = PresentationPDF()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.set_margins(15, 15, 15)

    pdf.cover()

    # 1. Elevator pitch
    pdf.add_page()
    pdf.section_title("1. Elevator Pitch (30 seconds)")
    pdf.body(
        "Booqly is a cross-platform mobile and web application built with Flutter "
        "that helps users discover books, manage a personal library, track reading "
        "progress, read PDFs in-app, get AI-powered recommendations, and receive "
        "smart reading reminders based on their Google Calendar free time."
    )
    pdf.body(
        "The app solves a real problem: readers lose track of what they are reading, "
        "struggle to find their next book, and lack motivation to read consistently. "
        "Booqly combines a modern UI, cloud backend (Firebase), and AI (Google Gemini) "
        "into one integrated reading companion."
    )

    pdf.sub_title("One-sentence summary")
    pdf.body(
        '"Booqly is a Flutter-based reading companion that uses Firebase for auth and '
        'data, Gemini AI for personalized book chat, and Google Calendar to schedule '
        'reading reminders during free time."'
    )

    # 2. Problem & Solution
    pdf.section_title("2. Problem Statement & Solution")
    pdf.sub_title("Problems addressed")
    pdf.bullet("Scattered reading lists across notes, apps, and memory")
    pdf.bullet("No single place to track progress across multiple books")
    pdf.bullet("Difficulty discovering books aligned with personal interests")
    pdf.bullet("Low motivation and no habit-building support")
    pdf.bullet("No intelligent assistant to answer questions about owned books")

    pdf.sub_title("Our solution")
    pdf.bullet("Unified library with Reading / Want to Read / Completed tabs")
    pdf.bullet("In-app PDF reader with page-level progress sync to the cloud")
    pdf.bullet("Genre-based onboarding and Discover feed for recommendations")
    pdf.bullet("AI chat grounded in the user's library, preferences, and reviews")
    pdf.bullet("Calendar-aware local notifications during free time slots")

    # 3. Key Features
    pdf.add_page()
    pdf.section_title("3. Main Features to Demonstrate")

    pdf.sub_title("Authentication & Onboarding")
    pdf.bullet("Email/password sign-up with 6-digit email verification")
    pdf.bullet("Google Sign-In (one-tap login)")
    pdf.bullet("Forgot password via Cloud Function + Gmail SMTP")
    pdf.bullet("First-time onboarding: pick genres, reading theme, and pace")

    pdf.sub_title("Home Dashboard")
    pdf.bullet("Continue Reading card with live progress")
    pdf.bullet("Want to Read carousel")
    pdf.bullet("Reading streak calendar and monthly stats")
    pdf.bullet("Bottom navigation: Home, Discover, Add, Friends, Settings")

    pdf.sub_title("Library & Discovery")
    pdf.bullet("Personal library with category filters and real-time Firestore sync")
    pdf.bullet("Search catalog by title or author")
    pdf.bullet("Book detail: progress slider, favorites, reviews, mark completed")
    pdf.bullet("Full-screen PDF reader (Syncfusion PDF viewer)")

    pdf.sub_title("AI Assistant (Ask AI)")
    pdf.bullet("Powered by Google Gemini API")
    pdf.bullet("Recommends books based on genres, library, and ratings")
    pdf.bullet("Can identify books from uploaded cover photos")
    pdf.bullet("Answers questions like ratings, summaries, and what to read next")

    pdf.sub_title("Social & Goals")
    pdf.bullet("Friends feed: follow users, see reading activity")
    pdf.bullet("Reading goals: yearly and daily targets with progress tracking")
    pdf.bullet("Reading Wrapped: year-in-review stats and highlights")
    pdf.bullet("Book notes and friend notes sharing")

    pdf.sub_title("Settings & Integrations")
    pdf.bullet("Google Calendar linking for free-time detection")
    pdf.bullet("Reading reminder notifications during calendar gaps (25+ min)")
    pdf.bullet("Light / Dark / System theme with saved preference")
    pdf.bullet("Profile management and sign out")

    # 4. Tech Stack
    pdf.add_page()
    pdf.section_title("4. Technology Stack")

    rows = [
        ("Frontend", "Flutter (Dart 3.11+), cross-platform: Android, iOS, Web, Windows"),
        ("Backend", "Firebase Auth, Cloud Firestore, Cloud Functions (Node.js)"),
        ("AI", "Google Gemini API (REST) via gemini_chat_service.dart"),
        ("Email", "Gmail SMTP through Firebase Cloud Functions (nodemailer)"),
        ("Calendar", "Google Calendar API + OAuth 2.0"),
        ("PDF", "Syncfusion Flutter PDF Viewer"),
        ("Fonts", "Google Fonts: Outfit (UI), Figtree (headers)"),
        ("State", "StatefulWidget, ValueNotifier, StreamBuilder, service singletons"),
        ("Persistence", "SharedPreferences (theme), Firestore (user data)"),
    ]
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_fill_color(238, 242, 255)
    pdf.cell(45, 7, "Layer", border=1, fill=True)
    pdf.cell(135, 7, "Technology", border=1, fill=True, ln=True)
    pdf.set_font("Helvetica", "", 9)
    for layer, tech in rows:
        pdf.cell(45, 7, layer, border=1)
        pdf.cell(135, 7, tech, border=1, ln=True)
    pdf.ln(4)

    pdf.sub_title("Why Flutter?")
    pdf.body(
        "Single codebase runs on mobile, web, and desktop. Fast UI development with "
        "hot reload. Strong ecosystem for Firebase and Google services integration."
    )

    pdf.sub_title("Why Firebase?")
    pdf.body(
        "Provides authentication, real-time database, serverless functions, and "
        "security rules without managing our own backend servers. Scales automatically "
        "and integrates natively with Flutter."
    )

    # 5. Architecture
    pdf.add_page()
    pdf.section_title("5. Application Architecture")

    pdf.sub_title("Project structure (lib/)")
    pdf.bullet("Pages/ - UI screens (Welcome, Login, Home, Library, BookDetail, etc.)")
    pdf.bullet("services/ - Business logic (auth, library, AI chat, calendar, email)")
    pdf.bullet("models/ - Data classes (Book, Feedback, Preferences, ChatMessage)")
    pdf.bullet("theme/ - Centralized colors, ThemeData, typography, theme switching")
    pdf.bullet("widgets/ - Reusable components (auth scaffold, calendar dialog)")

    pdf.sub_title("Data flow example: updating reading progress")
    pdf.numbered(1, "User moves progress slider on BookDetailPage")
    pdf.numbered(2, "library_service.dart writes to Firestore: users/{uid}/library/{bookId}")
    pdf.numbered(3, "Firestore real-time listener on LibraryPage receives update")
    pdf.numbered(4, "UI rebuilds automatically with new progress percentage")

    pdf.sub_title("Auth flow")
    pdf.body(
        "Welcome -> Login/Signup -> (optional) Reading Preferences onboarding -> "
        "AuthGate checks Firebase Auth session -> HomePage. AuthGate uses StreamBuilder "
        "on authStateChanges() to react to login/logout instantly."
    )

    # 6. Firebase
    pdf.section_title("6. Firebase Backend")

    pdf.sub_title("Firestore collections")
    pdf.bullet("books/{bookId} - Global catalog (title, author, cover, PDF URL, pages)")
    pdf.bullet("books/{bookId}/feedbacks - User reviews and star ratings")
    pdf.bullet("users/{uid} - Profile (name, email)")
    pdf.bullet("users/{uid}/library/{bookId} - Personal shelf (status, progress)")
    pdf.bullet("users/{uid}/favorites/{bookId} - Favorited books")
    pdf.bullet("preferences/{uid} - Genres, theme, pace from onboarding")
    pdf.bullet("email_index/{email} - Prevents duplicate sign-ups")

    pdf.sub_title("Cloud Functions (Node.js)")
    pdf.bullet("sendAuthEmail - Sends verification codes and welcome emails via Gmail")
    pdf.bullet("sendPasswordResetEmail - Sends password reset links")

    pdf.sub_title("Security")
    pdf.body(
        "firestore.rules enforces that users can only read/write their own data. "
        "Books catalog is readable by authenticated users. Feedback requires auth. "
        "Email index is server-managed to prevent account duplication attacks."
    )

    # 7. UI Theme
    pdf.add_page()
    pdf.section_title("7. UI / UX & Theme System")

    pdf.body(
        "The app uses a unified design system with Light and Dark modes. All screens "
        "read colors from a central AppPalette via AppColors.of(context). Users can "
        "choose Light, Dark, or System mode in Settings; preference is saved with "
        "SharedPreferences."
    )

    pdf.sub_title("Design tokens")
    pdf.bullet("Primary brand color: Indigo (#4F46E5 light / #6366F1 dark)")
    pdf.bullet("Typography: Outfit for body text, Figtree for page headers")
    pdf.bullet("Consistent spacing, border radius, card shadows, and elevation")
    pdf.bullet("WCAG-friendly contrast: off-white surfaces, not pure black/white")

    pdf.sub_title("Screens to show theme switching")
    pdf.body(
        "Open Settings -> Theme section -> toggle Light / Dark / System. Navigate to "
        "Library, Discover, and Profile to show consistent theming across the app."
    )

    # 8. Demo script
    pdf.section_title("8. Recommended Live Demo (5-8 minutes)")

    pdf.numbered(1, "Welcome screen - explain the app's purpose and tagline")
    pdf.numbered(2, "Sign in (Google or email) - show authentication")
    pdf.numbered(3, "Home dashboard - Continue Reading, Want to Read, streak")
    pdf.numbered(4, "Discover tab - browse books by genre")
    pdf.numbered(5, "Tap a book -> Book Detail - progress, reviews, Start Reading")
    pdf.numbered(6, "Open PDF reader briefly - in-app reading experience")
    pdf.numbered(7, "Library tab - Reading / Want to Read / Completed filters")
    pdf.numbered(8, "Ask AI - ask 'What should I read next?' or 'Rate Atomic Habits'")
    pdf.numbered(9, "Friends tab - social reading feed (if demo account has data)")
    pdf.numbered(10, "Settings - Theme picker, Calendar link, Reading goals link")

    pdf.sub_title("Run the app")
    pdf.body(
        "git clone https://github.com/AliRaya26/BooqlyProject.git\n"
        "cd BooqlyProject\n"
        "flutter pub get\n"
        "flutter run -d chrome --web-hostname=localhost --web-port=54141"
    )

    # 9. Q&A
    pdf.add_page()
    pdf.section_title("9. Likely Professor Questions & Answers")

    qa = [
        (
            "What makes your project different from Goodreads or Kindle?",
            "Booqly combines library management, in-app PDF reading, AI recommendations "
            "grounded in the user's own library, calendar-based reading reminders, and "
            "social features in one Flutter app with a custom Firebase backend.",
        ),
        (
            "How does the AI assistant work?",
            "We call Google Gemini API with a system prompt that includes the user's "
            "genres, current library, book catalog, and review data. The AI answers "
            "in context. Users can also upload book cover images for visual identification.",
        ),
        (
            "How is data stored and secured?",
            "Firebase Firestore with security rules. Each user can only access their own "
            "library, preferences, and notes. Authentication via Firebase Auth (email + Google).",
        ),
        (
            "What was the hardest technical challenge?",
            "Integrating multiple Google services (Auth, Calendar, Gemini) with consistent "
            "OAuth configuration across web and mobile, plus building a unified theme system "
            "that works across 20+ screens.",
        ),
        (
            "What is not fully implemented?",
            "ISBN barcode scan and manual book entry are partially built. Some dashboard "
            "stats use sample UI data. Calendar reminders work best on web/Android.",
        ),
        (
            "How did you test the app?",
            "Manual testing on Chrome web and Flutter emulators. Firebase console for "
            "data verification. Cloud Function logs for email delivery testing.",
        ),
        (
            "What would you add next?",
            "Push notifications via FCM, offline reading cache, audiobook support, "
            "reading clubs, and full ISBN lookup integration.",
        ),
    ]

    for q, a in qa:
        pdf.sub_title(f"Q: {q}")
        pdf.body(f"A: {a}")
        pdf.ln(1)

    # 10. Summary
    pdf.add_page()
    pdf.section_title("10. Closing Summary")

    pdf.body(
        "Booqly demonstrates full-stack mobile development skills: Flutter UI, Firebase "
        "backend, third-party API integration (Gemini, Google Calendar), email automation "
        "via Cloud Functions, real-time data sync, and a production-quality theme system."
    )

    pdf.sub_title("Key numbers to mention")
    pdf.bullet("60+ Dart source files across pages, services, models, and theme")
    pdf.bullet("5 main navigation tabs + 15+ feature screens")
    pdf.bullet("Cross-platform: Android, iOS, Web, Windows, macOS, Linux")
    pdf.bullet("Firebase project: booqlyapp-83777")
    pdf.bullet("GitHub: github.com/AliRaya26/BooqlyProject")

    pdf.sub_title("Suggested closing line")
    pdf.body(
        '"Booqly shows how modern cross-platform tools and cloud services can turn '
        'reading from a passive habit into an intelligent, social, and motivating '
        'experience - all from a single Flutter codebase."'
    )

    pdf.ln(10)
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(120, 120, 120)
    pdf.multi_cell(
        0,
        5,
        "Tip: Practice the demo flow twice before presenting. Have a test account "
        "logged in with books in your library so Continue Reading and AI chat have "
        "real data to show.",
    )

    import os
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    pdf.output(OUTPUT)
    print(f"PDF created: {OUTPUT}")


if __name__ == "__main__":
    build()
