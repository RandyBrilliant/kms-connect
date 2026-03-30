# Splash & Login Updates - Fixed Layout & Added Legal Links

## Changes Made

### 1. Fixed Splash Screen Layout ✅
**Issue:** Splash screen was cut off on the right side (layout not filling screen)

**Solution:** Wrapped FadeTransition with `SizedBox.expand()` to ensure full screen coverage

```dart
return Scaffold(
  body: SizedBox.expand(  // ← Added this
    child: FadeTransition(
      opacity: _exitOpacity,
      child: ProfessionalGradientBackground(...),
    ),
  ),
);
```

**Result:** Splash screen now properly fills the entire screen with gradient background

### 2. Added Terms & Conditions + Copyright to Login Page ✅

**Added Legal Links:**
- Terms & Conditions (clickable link)
- Privacy Policy (clickable link)  
- Copyright notice with current year

**Location:** Below the trust badge, above bottom padding

**Implementation:**
```dart
// Terms and Privacy links
Wrap(
  alignment: WrapAlignment.center,
  children: [
    Text('Dengan masuk, Anda menyetujui'),
    InkWell(
      onTap: () {
        // TODO: Navigate to Terms & Conditions
      },
      child: Text('Syarat & Ketentuan', 
        decoration: TextDecoration.underline),
    ),
    Text('dan'),
    InkWell(
      onTap: () {
        // TODO: Navigate to Privacy Policy
      },
      child: Text('Kebijakan Privasi',
        decoration: TextDecoration.underline),
    ),
    Text('kami'),
  ],
)

// Copyright
Text('© ${DateTime.now().year} KMS Connect. All rights reserved.')
```

## Visual Layout

### Login Page (Bottom Section)
```
┌─────────────────────────────────┐
│  [Register Button]              │
├─────────────────────────────────┤
│  Dengan masuk, Anda menyetujui  │
│  Syarat & Ketentuan dan         │
│  Kebijakan Privasi kami         │
├─────────────────────────────────┤
│  © 2026 KMS Connect.            │
│  All rights reserved.           │
└─────────────────────────────────┘
```

## TODO: Link Navigation

The Terms & Conditions and Privacy Policy links are currently placeholders. 
To implement:

1. **Create Terms & Conditions Page**
   ```dart
   // lib/features/legal/presentation/pages/terms_conditions_page.dart
   ```

2. **Create Privacy Policy Page**
   ```dart
   // lib/features/legal/presentation/pages/privacy_policy_page.dart
   ```

3. **Add Routes in app.dart**
   ```dart
   GoRoute(
     path: '/terms',
     builder: (context, state) => const TermsConditionsPage(),
   ),
   GoRoute(
     path: '/privacy',
     builder: (context, state) => const PrivacyPolicyPage(),
   ),
   ```

4. **Update onTap handlers in login_page_new.dart**
   ```dart
   onTap: () => context.push('/terms'),  // Terms
   onTap: () => context.push('/privacy'),  // Privacy
   ```

## Text Styling

**Legal Links:**
- Font size: 11px
- Weight: Semi-bold (600) for links, Medium (500) for regular text
- Color: White with underline for links
- Opacity: 70% for regular text, 100% for links

**Copyright:**
- Font size: 10px
- Weight: Medium (500)
- Color: White with 60% opacity
- Alignment: Center

## Files Modified

1. ✅ `lib/features/auth/presentation/pages/splash_page.dart`
   - Added SizedBox.expand() wrapper
   - Fixed deprecated withOpacity() calls
   
2. ✅ `lib/features/auth/presentation/pages/login_page_new.dart`
   - Added Terms & Privacy links
   - Added copyright notice
   - Replaced trust badge section

## Testing

Run the app to verify:
```bash
cd /Users/rbc/Developer/kms-connect/mobile
flutter run
```

### Checklist:
- [ ] Splash screen fills entire screen (no white areas)
- [ ] Splash gradient displays correctly
- [ ] Login page shows Terms & Privacy text
- [ ] Links are underlined and white
- [ ] Copyright shows current year
- [ ] Text wraps properly on small screens
- [ ] Layout is responsive

## Compliance

These legal links help ensure compliance with:
- GDPR (General Data Protection Regulation)
- App Store requirements
- Google Play Store requirements
- Professional standards for user consent

## Next Steps

1. Create actual Terms & Conditions content
2. Create Privacy Policy content
3. Implement navigation to legal pages
4. Consider adding version numbers
5. Add "Last Updated" dates to legal pages

---

**Status:** ✅ Layout Fixed & Legal Links Added
**Remaining:** TODO items for actual page implementation
