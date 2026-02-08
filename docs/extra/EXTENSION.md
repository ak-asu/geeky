# Geeky - Browser Extension Development Guide

## Project Overview
Geeky is a cross-browser Manifest V3 extension for comprehensive note-taking and web content capture. Built with React 18 + TypeScript, Firebase backend, and Vite bundler targeting Chrome, Firefox, Safari, and Edge.

**Vision**: Universal web clipper with advanced highlighting, metadata extraction, hierarchical organization, and offline-first sync.

## Technology Stack

### Core Technologies
- **Frontend**: React 18.3, TypeScript 5.5, Tailwind CSS 3.4
- **State Management**: Zustand 4.5 with persist middleware
- **Build System**: Vite 5.4 with custom rollup config for multi-entry extension
- **Backend**: Firebase 10.14 (Firestore, Auth, Storage, Functions planned)
- **Extension**: Manifest V3 (Chrome service workers, cross-browser polyfills)

### Key Dependencies
- **Content Processing**: 
  - `@mozilla/readability` - Article extraction algorithm
  - `turndown` - HTML → Markdown conversion
  - `dompurify` - XSS sanitization
- **Search**: `fuse.js` - Fuzzy search with weighted scoring
- **Forms**: `react-hook-form` - Form validation and state
- **Routing**: `react-router-dom` - Client-side navigation (future web app)
- **Utilities**: `date-fns` - Date formatting and manipulation
- **Icons**: `lucide-react` - Icon library (optimized imports)
- **Hotkeys**: `react-hotkeys-hook` - Keyboard shortcut management

### Dev Dependencies
- **Testing**: Vitest 1.0 (unit tests, no chrome.* mocks yet)
- **Linting**: ESLint 9 with TypeScript-ESLint, React hooks plugin
- **Type Safety**: `@types/chrome`, `@types/dompurify`, `@types/turndown`
- **Cross-Browser**: `webextension-polyfill` (installed, not yet integrated)

## Architecture

### Extension Structure (Manifest V3)
Three separate contexts that communicate via chrome APIs:

1. **Background Service Worker** ([src/background.ts](../src/background.ts))
   - Context menus (11 items: save page/selection/link/image, highlight, extract, sidebar, quick note)
   - Keyboard shortcuts (quick-save, highlight-selection, open-sidebar)
   - Message router for content/popup communication
   - Tab lifecycle management (injection, cleanup)
   - Offline sync queue with network status detection

2. **Content Script** ([src/content.ts](../src/content.ts))
   - Runs on all URLs (`<all_urls>` manifest permission)
   - Highlight rendering with DOM mutation observer
   - Sidebar iframe injection/removal
   - Selection handling and text extraction
   - Persistent port connection to background
   - Isolated world (no direct access to page JS)

3. **Popup/Sidebar UI** (React apps)
   - **Popup**: [PopupApp.tsx](../src/components/popup/PopupApp.tsx) - 4 tabs (Saved, Highlights, Tags, Settings)
   - **Sidebar**: [sidebar.html](../public/sidebar.html) - Page highlights + quick actions (vanilla JS, not React yet)
   - Dimensions: Popup 384x384px, Sidebar 400px fixed width

### Communication Patterns
```typescript
// One-off messages (background ↔ content/popup)
chrome.runtime.sendMessage({ type: 'SAVE_CONTENT', payload: {...} }, response => {...})

// Long-lived connections (content → background)
const port = chrome.runtime.connect({ name: 'content-script' });
port.postMessage({ type: 'HIGHLIGHT_CREATED', data: {...} });

// Background → specific tab
chrome.tabs.sendMessage(tabId, { type: 'TOGGLE_SIDEBAR' });
```

### State Management Architecture
**Dual-layer state**: Zustand for UI, chrome.storage for extension

- **Zustand Store** ([useExtensionStore.ts](../src/stores/useExtensionStore.ts))
  - Persisted to localStorage (not chrome.storage)
  - Used only in React components (popup/sidebar)
  - State: savedContent[], highlights[], tags[], templates[], settings, UI state
  - Actions: CRUD operations + search/filter/sort helpers

- **chrome.storage API**
  - Used in background/content scripts
  - Local storage for offline queue (max 1000 items)
  - Sync disabled (Firebase handles cross-device sync)

- **Firebase Real-time Sync**
  - `onSnapshot()` subscriptions in PopupApp `loadUserData()`
  - Automatic store updates on Firestore changes
  - Search indices rebuilt on content updates

### Data Flow
```
User Action (popup/content)
  → Message to background
    → firebaseService operation
      → Firestore write (with Timestamp conversion)
        → onSnapshot callback
          → Zustand store update
            → React re-render
```

## Core Services & Algorithms

### 1. Content Extraction ([contentExtractor.ts](../src/services/contentExtractor.ts))

**Algorithm**: Multi-stage content extraction with fallbacks

1. **Primary: Mozilla Readability**
   - Parses HTML into DOM
   - Readability algorithm extracts main article
   - Returns structured content (title, byline, excerpt, content)

2. **Secondary: CSS Selector Cascade**
   - Tries common selectors: `article`, `[role="main"]`, `.main-content`, `.content`, `.post-content`, `.entry-content`, `main`
   - DOMPurify sanitizes HTML
   - Turndown converts to Markdown

3. **Fallback: Body Text**
   - Returns first 5000 chars of body.textContent

**Metadata Extraction**:
- **Schema.org**: Parses `<script type="application/ld+json">` for Article/NewsArticle
- **OpenGraph**: Extracts `og:title`, `og:description`, `og:image`, etc.
- **Heuristics**: CSS selectors for author (`[rel="author"]`, `.author`, `.byline`), publish date (`time[datetime]`, `.published`), images (first 10 non-data URIs)
- **Reading metrics**: Word count, estimated reading time (200 wpm)

**Turndown Configuration**:
```typescript
new TurndownService({
  headingStyle: "atx",        // # Markdown headers
  codeBlockStyle: "fenced"    // ``` code blocks
})
```

### 2. Search Service ([searchService.ts](../src/services/searchService.ts))

**Algorithm**: Fuse.js fuzzy search with weighted fields

**Content Search Config**:
- **Keys**: title (40%), content (30%), excerpt (20%), tags (10%)
- **Threshold**: 0.3 (balance precision/recall)
- **Features**: Score ranking, match highlighting

**Highlight Search Config**:
- **Keys**: text (60%), note (30%), context (10%)
- **Threshold**: 0.3

**Operations**:
- `initializeContentSearch()` - Rebuild index on data load/sync
- `searchContent(query)` - Fuzzy search, returns sorted by relevance
- `filterContentByTags(content, tags)` - AND logic (all tags must match)
- `sortContent(sortBy)` - Date (newest first), Title (lexicographic), Relevance (Fuse score)

### 3. Firebase Service ([firebaseService.ts](../src/services/firebaseService.ts))

**Firestore Schema**:

```typescript
// Collection: savedContent
{
  id: string (auto-generated)
  userId: string (indexed)
  url: string
  title: string
  content: string (markdown)
  excerpt: string (200 chars)
  tags: string[]
  template?: string
  metadata: {
    author?, publishedDate?, siteName?, description?, images[], 
    ogData?, schemaData?, wordCount?, readingTime?
  }
  highlights: Highlight[] (denormalized)
  notes: string
  createdAt: Timestamp
  updatedAt: Timestamp
  isArchived: boolean
  isFavorite: boolean
}

// Collection: highlights
{
  id: string
  userId: string (indexed)
  url: string (indexed)
  pageTitle: string
  text: string
  context: string (500 chars)
  selector: string (CSS/XPath)
  color: string (hex)
  note?: string
  createdAt: Timestamp
  updatedAt: Timestamp
}

// Collection: tags
{
  id: string
  userId: string (indexed)
  name: string
  color: string
  parent?: string (hierarchical support)
  usageCount: number
  createdAt: Timestamp
}

// Collection: templates
{
  id: string
  userId: string (indexed)
  name: string
  urlPattern: string (regex)
  selectors: [{
    name: string
    selector: string (CSS)
    attribute?: string
    required: boolean
    type: "text" | "html" | "attribute" | "image"
  }]
  isActive: boolean
  createdAt: Timestamp
  updatedAt: Timestamp
}
```

**Critical Pattern: Date ↔ Timestamp Conversion**
```typescript
// Always convert when writing to Firestore
createdAt: Timestamp.fromDate(content.createdAt)

// Always convert when reading from Firestore
createdAt: doc.data().createdAt.toDate()
```

**Query Pattern**: Always filter by `userId` + sort by `createdAt desc`
```typescript
query(collection(db, "savedContent"), 
      where("userId", "==", userId), 
      orderBy("createdAt", "desc"))
```

**Real-time Subscriptions**:
- `subscribeToUserContent()` - onSnapshot listener
- Auto-updates Zustand store on remote changes
- Cleanup with `unsubscribeAll()` on unmount

**Authentication**:
- Email/password via Firebase Auth
- `onAuthStateChanged()` listener in PopupApp
- Triggers `loadUserData()` Promise.all for parallel fetch

### 4. Highlight System

**Highlight Lifecycle**:
1. User selects text in content script
2. Generate CSS selector for range (fallback to text search)
3. Wrap text nodes in `<span class="web-clipper-highlight">`
4. Send to background → Firebase
5. On page reload: Query highlights by URL → Re-inject spans

**Selector Generation**:
- Prefer element ID: `#unique-id`
- Fallback to class chain: `article.post-content`
- Store text + context (500 chars) for text-based matching

**DOM Mutation Observer**:
- Watches for dynamic content changes
- Restores highlights if DOM elements removed/replaced
- Debounced to prevent performance issues

**Highlight Mode**:
- Toggled via keyboard shortcut or context menu
- Changes cursor to crosshair
- Shows floating indicator
- Auto-saves selection on mouseup

## Development Workflows

### Build Commands
```bash
pnpm dev                   # Watch mode, HMR for React
pnpm build                 # Generic production build
pnpm build:chrome          # Chrome-specific (uses side_panel API)
pnpm build:firefox         # Firefox adaptations (no side_panel)
pnpm build:safari          # Safari compatibility
pnpm build:edge            # Edge (same as Chrome)
pnpm lint                  # ESLint check
pnpm lint:fix              # Auto-fix linting issues
pnpm format                # Prettier formatting
pnpm test                  # Vitest unit tests
```

### Vite Build Configuration

**Multiple Entry Points** (defined in [vite.config.ts](../vite.config.ts)):
- `main`: index.html (React app entry)
- `background`: src/background.ts (service worker)
- `content`: src/content.ts (content script)

**Critical: Fixed Output Names**
```typescript
entryFileNames: (chunkInfo) => {
  if (chunkInfo.name === "background") return "background.js";  // Manifest references this
  if (chunkInfo.name === "content") return "content.js";        // Manifest references this
  return "assets/[name]-[hash].js";                              // React chunks
}
```

**Why?** Manifest V3 requires exact filenames in `background.service_worker` and `content_scripts[].js`.

**Build Output** (`dist/`):
```
dist/
  background.js          # Service worker (no imports allowed in MV3)
  content.js             # Content script
  popup.html             # From public/
  sidebar.html           # From public/
  manifest.json          # From public/
  assets/
    index-[hash].js      # React bundle
    index-[hash].css     # Tailwind output
  icons/                 # From public/icons/
```

### Loading Extension for Testing
1. Run `pnpm build:chrome`
2. Chrome: Navigate to `chrome://extensions`
3. Enable "Developer mode" (top-right toggle)
4. Click "Load unpacked" → Select `dist/` folder
5. Note extension ID (needed for filtering console logs)

### Debugging Contexts

**Background Service Worker**:
- chrome://extensions → Find Geeky → Click "Service Worker"
- Console shows background.ts logs
- Service worker sleeps after 30s inactivity (Manifest V3 limitation)

**Content Script**:
- Inspect page (right-click → Inspect)
- Console → Filter by extension ID
- Content script runs in every tab matching `<all_urls>`

**Popup**:
- Right-click extension icon → Inspect popup
- DevTools opens in separate window
- Closes when popup closes

**Network Requests**:
- Background/content: Check in respective DevTools
- Popup: Visible in popup's DevTools Network tab

### Hot Reload Limitations
- Background/content scripts require extension reload after changes
- React popup/sidebar support HMR in `pnpm dev` mode
- Use `Ctrl+R` in chrome://extensions to reload extension

## Code Patterns & Conventions

### TypeScript Type System
All types in [src/types/extension.ts](../src/types/extension.ts)

**Interface Hierarchy**:
- `SavedContent` - Main content entity (16 fields)
- `ContentMetadata` - Rich metadata (9 optional fields)
- `Highlight` - Text annotation (11 fields)
- `Template` - Extraction rules (8 fields)
- `Tag` - Hierarchical labels (7 fields)
- `UserSettings` - Preferences (8 fields)
- `ExtensionMessage` - IPC type definitions (3 fields)

**Convention**: All date fields typed as `Date`, converted to `Timestamp` at Firebase boundary.

### Component Organization
```
src/components/
  ui/                    # Reusable primitives (Button, Input, LoadingSpinner)
  popup/                 # Popup-specific features
    PopupApp.tsx         # Root component (auth check)
    AuthScreen.tsx       # Sign in/up forms
    MainScreen.tsx       # Authenticated view (tab router)
    TabNavigation.tsx    # Tab switcher
    QuickActions.tsx     # Quick save buttons
    SearchBar.tsx        # Fuzzy search input
    tabs/
      SavedContentTab.tsx
      HighlightsTab.tsx
      TagsTab.tsx
      SettingsTab.tsx
```

**Pattern**: Each tab imports from Zustand store, renders filtered/sorted data.

### Styling Approach
- **Tailwind utility-first** (no custom CSS files yet)
- **Popup dimensions**: Fixed 384x384px (defined in PopupApp className)
- **Sidebar**: 400px width, 100vh height, injected iframe
- **Color palette**: Blue primary (#2563eb), Gray neutrals, Yellow highlights (#fbbf24)

### Stub Pattern for Incomplete Features
Many methods in [background.ts](../src/background.ts) are stubs with TODO comments:

```typescript
async saveLink(_info: MenuClickInfo, _tab: chrome.tabs.Tab) {
  // TODO: Implement saveLink functionality
  this.showNotification("Not implemented", "Save link is not implemented yet", "info");
}
```

**Why?** Allows extension to load without runtime errors while features are being built.

**Stub List** (lines 18-91):
- `saveLink()`, `saveImage()`, `extractContent()`, `openQuickNote()`
- `saveContent()`, `saveHighlight()`, `getPageHighlights()`
- `extractPageContent()`, `getUserSettings()`, `updateUserSettings()`
- `handleTabComplete()`, `handleContentSelection()`, `analyzePageContent()`

### Error Handling
- **Background**: Try-catch with notification fallback
- **Firebase**: Catch errors, log to console, don't throw (prevents popup crash)
- **Content Script**: Fail silently (page must not break)

## Chrome Extension APIs Used

### Permissions (from manifest.json)
- `storage` - chrome.storage.local for offline queue
- `activeTab` - Access current tab on user action
- `contextMenus` - Right-click menu items
- `scripting` - Dynamic script/CSS injection
- `webNavigation` - Page load detection (onCompleted)
- `offscreen` - Future: offscreen documents for background tasks
- `notifications` - Toast notifications
- `sidePanel` - Chrome-only sidebar API

### Key API Patterns

**Context Menus**:
```typescript
chrome.contextMenus.create({
  id: "save-selection",
  title: "Save selected text",
  contexts: ["selection"]
});
```

**Dynamic Script Injection**:
```typescript
chrome.scripting.executeScript({
  target: { tabId },
  func: () => document.documentElement.outerHTML  // Serializable function
});
```

**Keyboard Shortcuts** (manifest.json commands):
```json
"commands": {
  "quick-save": { "suggested_key": { "default": "Ctrl+Shift+S" } }
}
```

## Cross-Browser Compatibility

### Browser Support Targets
- Chrome 88+ (Manifest V3 stable)
- Firefox 78+ (Manifest V3 support limited)
- Safari 14+ (Manifest V3 partial)
- Edge 88+ (Chromium-based, same as Chrome)

### Known Differences
1. **Side Panel API**: Chrome-only
   - Firefox: Inject sidebar iframe into page content
   - Safari: Use popover API

2. **Service Worker Persistence**: Chrome kills after 30s inactivity
   - Use alarms API for scheduled tasks
   - Store state in chrome.storage, not memory

3. **Browser Polyfill**: `webextension-polyfill` installed but not imported yet
   - Normalizes `browser.*` vs `chrome.*` APIs
   - TODO: Import in background.ts and content.ts

4. **Content Security Policy**: Manifest V3 disallows eval, inline scripts
   - No `new Function()`, no `eval()`
   - All scripts must be bundled

## Firebase Configuration

**Environment Variables** (in [src/config/firebase.ts](../src/config/firebase.ts)):
```typescript
import.meta.env.VITE_FIREBASE_API_KEY
import.meta.env.VITE_FIREBASE_AUTH_DOMAIN
import.meta.env.VITE_FIREBASE_PROJECT_ID
import.meta.env.VITE_FIREBASE_STORAGE_BUCKET
import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID
import.meta.env.VITE_FIREBASE_APP_ID
```

**Vite env files**:
- `.env.local` - Local development secrets (gitignored)
- `.env.production` - Production config

**Firebase Services Initialized**:
- Firestore (`db`) - NoSQL document database
- Auth (`auth`) - Email/password authentication
- Storage (`storage`) - File uploads (not used yet)

**Security Rules** (not in repo):
- All reads/writes require `request.auth.uid == resource.data.userId`
- Indexes on `userId` + `createdAt` for performant queries

## Feature Requirements (from RESEARCH.md)

### Implemented
✅ Save entire pages (HTML extraction)
✅ Save selected text with context
✅ Extract main content (Readability)
✅ Real-time highlighting with persistence
✅ Highlight synchronization (Firebase)
✅ Hierarchical tags (parent field)
✅ Full-text search (Fuse.js)
✅ Context menu integration
✅ Keyboard shortcuts
✅ Offline queue with sync

### Planned (Not Implemented)
- RSS feed integration and monitoring
- Twitter thread capture
- Drag-and-drop file upload
- Mobile share sheet
- Audio-based highlighting (AirPods)
- Custom template visual editor
- Automatic template matching
- AI-powered auto-highlighting
- Speech-to-text notes
- Export formats (JSON, CSV, PDF)

## Performance Constraints (from RESEARCH.md)

**Targets**:
- Max 50MB extension size (current: ~5MB)
- Support 10,000+ items per user (tested: ~100)
- Search response < 200ms (achieved with Fuse.js)
- Lazy loading for large lists (TODO)

**Optimization Strategies**:
- Firestore pagination (not implemented yet)
- Virtual scrolling for long lists (not implemented)
- Debounced search input
- Indexed queries (userId + createdAt)
- Service worker sleep → chrome.storage for persistence

## Common Development Tasks

### Adding a Content Capture Method
1. Add context menu item in `BackgroundService.setupContextMenus()`
2. Add handler in `BackgroundService.handleContextMenuClick()`
3. Implement extraction logic in [contentExtractor.ts](../src/services/contentExtractor.ts)
4. Add Firebase save method in [firebaseService.ts](../src/services/firebaseService.ts)
5. Update Zustand store action in [useExtensionStore.ts](../src/stores/useExtensionStore.ts)
6. Add UI component in popup tabs

### Adding a Popup Tab
1. Create component in [src/components/popup/tabs/](../src/components/popup/tabs/)
2. Import in [MainScreen.tsx](../src/components/popup/MainScreen.tsx) `renderCurrentTab()`
3. Add tab definition in [TabNavigation.tsx](../src/components/popup/TabNavigation.tsx)
4. Update `currentTab` type in store if needed

### Implementing a Stub Method
1. Find stub with `// TODO:` comment in [background.ts](../src/background.ts)
2. Replace notification with actual logic
3. Add Firebase operation if needed
4. Test in loaded extension
5. Remove `_` prefix from unused params

### Adding Firebase Collection
1. Define interface in [src/types/extension.ts](../src/types/extension.ts)
2. Add CRUD methods in [firebaseService.ts](../src/services/firebaseService.ts)
3. Add Zustand store slice in [useExtensionStore.ts](../src/stores/useExtensionStore.ts)
4. Create Firestore security rules
5. Add composite index in Firebase console