const RELEASES = 'https://github.com/txngerine/zon/releases/latest'
const REPO = 'https://github.com/txngerine/zon'

const PLATFORMS = [
  {
    id: 'macos',
    name: 'macOS',
    detail: 'Apple Silicon',
    file: 'zon-macos-arm64.zip',
    match: /Mac/,
  },
  {
    id: 'windows',
    name: 'Windows',
    detail: 'x64',
    file: 'zon-windows-x64.zip',
    match: /Win/,
  },
  {
    id: 'linux',
    name: 'Linux',
    detail: 'x64',
    file: 'zon-linux-x64.tar.gz',
    match: /Linux|X11/,
  },
]

const FEATURES = [
  {
    title: 'Segmented HTTP engine',
    body: 'Splits files into up to 32 parallel byte ranges. Resumes after pause, quit or crash, retries with backoff, and steps aside when a server answers 429.',
  },
  {
    title: 'Video & audio',
    body: 'YouTube, Shorts, playlists, Instagram, TikTok, X, Vimeo, SoundCloud and 1000+ sites via yt-dlp. Best, 4K, 1080p MP4, MP3 128–320 kbps or M4A.',
  },
  {
    title: 'BitTorrent',
    body: 'Magnet links and .torrent files through a private aria2 daemon: live peers, pause and resume with piece verification, optional seeding to a ratio.',
  },
  {
    title: 'Persistent library',
    body: 'Downloads, history and settings live in one file in the app-support folder. Interrupted transfers re-queue the next time you launch ZON.',
  },
  {
    title: 'Desktop integration',
    body: 'Tray icon with pause and resume, native notifications, launch at login, a copied-link banner, drag & drop, and a browser bookmarklet.',
  },
  {
    title: 'Queue control',
    body: 'Global and per-download speed limits, priorities and drag-to-reorder queueing. Stalled torrents stop occupying download slots.',
  },
]

const TOOLS = [
  { name: 'yt-dlp', note: 'Installed from Settings › Media in one click' },
  { name: 'ffmpeg', note: 'Bundled, unpacked on first launch' },
  { name: 'aria2', note: 'Bundled on Windows and Linux' },
]

function detectPlatform() {
  const ua = navigator.userAgent
  return PLATFORMS.find((p) => p.match.test(ua)) || PLATFORMS[0]
}

function Nav() {
  return (
    <header className="nav">
      <a className="brand" href="#top">
        <img src="/favicon.png" alt="" width="20" height="20" />
        <span>ZON</span>
      </a>
      <nav>
        <a href="#features">Features</a>
        <a href="#download">Download</a>
        <a href={REPO}>GitHub</a>
      </nav>
    </header>
  )
}

function Hero() {
  const current = detectPlatform()
  return (
    <section className="hero" id="top">
      <p className="eyebrow">macOS · Windows · Linux</p>
      <h1>The download manager.</h1>
      <p className="lede">
        Segmented HTTP, video and audio, and torrents — one quiet desktop app
        that picks up where it left off.
      </p>
      <div className="actions">
        <a className="btn btn-solid" href={RELEASES}>
          Download for {current.name}
        </a>
        <a className="btn" href="#download">
          All platforms
        </a>
      </div>
      <p className="meta">Free and open source · Built with Flutter</p>
    </section>
  )
}

function Features() {
  return (
    <section className="section" id="features">
      <div className="section-head">
        <p className="eyebrow">Features</p>
        <h2>Everything a download manager should do.</h2>
      </div>
      <div className="grid">
        {FEATURES.map((f, i) => (
          <article className="cell" key={f.title}>
            <span className="index">{String(i + 1).padStart(2, '0')}</span>
            <h3>{f.title}</h3>
            <p>{f.body}</p>
          </article>
        ))}
      </div>
    </section>
  )
}

function Tools() {
  return (
    <section className="section">
      <div className="section-head">
        <p className="eyebrow">Under the hood</p>
        <h2>The tools it needs come with it.</h2>
      </div>
      <ul className="rows">
        {TOOLS.map((t) => (
          <li key={t.name}>
            <span className="row-name">{t.name}</span>
            <span className="row-note">{t.note}</span>
          </li>
        ))}
      </ul>
    </section>
  )
}

function Download() {
  const current = detectPlatform()
  return (
    <section className="section" id="download">
      <div className="section-head">
        <p className="eyebrow">Download</p>
        <h2>Pick your platform.</h2>
      </div>
      <ul className="rows downloads">
        {PLATFORMS.map((p) => (
          <li key={p.id} className={p.id === current.id ? 'is-current' : ''}>
            <span className="row-name">
              {p.name}
              <em>{p.detail}</em>
            </span>
            <span className="row-file">{p.file}</span>
            <a className="btn btn-solid" href={RELEASES}>
              Download
            </a>
          </li>
        ))}
      </ul>
      <p className="note">
        Every build is also on{' '}
        <a href={`${REPO}/releases`}>GitHub Releases</a>. Source and CI live in{' '}
        <a href={REPO}>the repository</a>.
      </p>
    </section>
  )
}

function Footer() {
  return (
    <footer className="footer">
      <p>Only download content you have the right to download.</p>
      <p>
        <a href={REPO}>GitHub</a>
        <a href={`${REPO}/releases`}>Releases</a>
        <a href={`${REPO}/issues`}>Issues</a>
      </p>
    </footer>
  )
}

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Features />
        <Tools />
        <Download />
      </main>
      <Footer />
    </>
  )
}
