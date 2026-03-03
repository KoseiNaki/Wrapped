# Wrapped iOS - Quick Setup Checklist

## ✅ Pre-Flight Checklist

### Backend Setup
- [ ] Backend is running at `http://localhost:3000` (or deployed URL)
- [ ] Backend OAuth flow is working (test with curl or browser)
- [ ] Spotify app configured with correct redirect URI
- [ ] Backend redirect includes: `wrapped://oauth?code=...`

### Xcode Project Setup
- [ ] Created new iOS App project named "Wrapped"
- [ ] Selected SwiftUI interface
- [ ] Set minimum deployment to iOS 16.0+
- [ ] Deleted default `ContentView.swift`

### File Integration
- [ ] All 15 Swift files added to Xcode project
- [ ] `Info.plist` configured with `wrapped://` URL scheme
- [ ] Files organized in folders (Config, Models, Services, ViewModels, Views)
- [ ] All files have correct target membership

### Configuration
- [ ] `AppConfig.swift` has correct BASE_URL
- [ ] Production URL updated (if deploying)
- [ ] Keychain service identifier is appropriate

## 🚀 First Run

1. **Build the app** (⌘B)
   - Should compile without errors
   - Check for any missing imports or typos

2. **Run on simulator** (⌘R)
   - App should launch showing LoginView
   - "Connect Spotify" button visible

3. **Test OAuth flow**
   - Tap "Connect Spotify"
   - Safari sheet should open with Spotify login
   - After login, should redirect back to app
   - Should show HomeView with user profile

4. **Test History**
   - Tap "Sync Now (Dev)" to fetch data
   - Tap "View History" to see events
   - Pull to refresh should work
   - Scroll should load more items

5. **Test Settings**
   - Switch between localhost/production
   - Custom URL should save

6. **Test Logout**
   - Logout should return to LoginView
   - Restart app - should stay logged out
   - Login again - should restore session

## 🐛 Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| "Cannot find WrappedApp in scope" | Verify all files are added to target |
| OAuth doesn't redirect back | Check Info.plist URL scheme |
| "No backend response" | Verify backend is running and URL is correct |
| Keychain errors | Check bundle identifier matches |
| "Token not found" | First login to generate token |

## 📱 Device Testing

For testing on physical device with local backend:

1. Get your Mac's local IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
2. Update BASE_URL to: `http://YOUR_MAC_IP:3000`
3. Ensure Mac and iPhone on same network
4. Update Spotify redirect URI if needed

## 🎯 What You Should See

### LoginView
- Green music note icon
- "Wrapped" title
- "Connect Spotify" button

### After Login → HomeView
- User profile icon
- Display name (or "Spotify User")
- Spotify ID
- Last sync time
- Four buttons: View History, Sync Now, Settings, Logout

### HistoryView
- List of tracks with album art
- Track name, artist, album
- Played at timestamp
- Duration
- Explicit badge (if applicable)
- Pull to refresh
- Infinite scroll

### SettingsView
- Environment picker (Localhost/Production)
- Current base URL
- Custom URL field
- Save button

## 🎉 Success Criteria

Your app is working if:

✅ OAuth flow completes without errors
✅ Profile loads and displays user info
✅ History shows listening events with album art
✅ Pull-to-refresh fetches new data
✅ Settings can switch between URLs
✅ Logout clears token
✅ App restores session on restart
✅ 401 errors trigger auto-refresh

## 📚 Next Steps

Once basic functionality works:

1. Add app icon to Assets.xcassets
2. Customize color scheme
3. Add launch screen
4. Test on physical device
5. Add more analytics/visualizations
6. Submit to TestFlight (optional)

## 🆘 Getting Help

If stuck:

1. Check Xcode console for error logs
2. Verify backend is returning expected JSON
3. Use breakpoints in `APIClient` to debug network calls
4. Check Keychain is storing token correctly
5. Verify deep link is being captured in `onOpenURL`

---

**Ready to build?** Open Xcode, create the project, add these files, and hit ⌘R! 🚀
