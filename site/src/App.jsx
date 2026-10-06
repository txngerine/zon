import { useEffect } from 'react'

const RELEASES = 'https://github.com/txngerine/zon/releases/latest'
const REPO = 'https://github.com/txngerine/zon'

const PLATFORMS = [
  {
    id: 'macos',
    name: 'macOS',
    detail: 'Apple Silicon',
    file: 'zon-macos-arm64.zip',
    match: /Mac/,
    icon: 'laptop',
  },
  {
    id: 'windows',
    name: 'Windows',
    detail: 'x64',
    file: 'zon-windows-x64.zip',
    match: /Win/,
    icon: 'window',
  },
  {
    id: 'linux',
    name: 'Linux',
    detail: 'x64',
    file: 'zon-linux-x64.tar.gz',
    match: /Linux|X11/,
    icon: 'terminal',
  },
]

const SOURCES = [
  'YouTube',
  'Shorts',
  'Instagram',
  'TikTok',
  'X',
  'Vimeo',
  'SoundCloud',
  'Magnet links',
  '.torrent',
  'HTTP / HTTPS',
  '1000+ more via yt-dlp',
]

const STATS = [
  { value: '32', label: 'parallel byte ranges per file' },
  { value: '1000+', label: 'video and audio sites' },
  { value: '3', label: 'desktop platforms' },
  { value: '$0', label: 'free and open source' },
]

const FORMATS = ['Best', '4K', '1080p MP4', 'MP3 320', 'MP3 128', 'M4A']

const SMALL_FEATURES = [
  {
    icon: 'library',
    title: 'Persistent library',
    body: 'Downloads, history and settings live in one file in the app-support folder. Interrupted transfers re-queue the next time you launch ZON.',
  },
  {
    icon: 'tray',
    title: 'Desktop integration',
    body: 'Tray icon with pause and resume, native notifications, launch at login, a copied-link banner, drag & drop, and a browser bookmarklet.',
  },
  {
    icon: 'queue',
    title: 'Queue control',
    body: 'Global and per-download speed limits, priorities and drag-to-reorder queueing. Stalled torrents stop occupying download slots.',
  },
]

const TOOLS = [
  { name: 'yt-dlp', note: 'Installed from Settings › Media in one click' },
  { name: 'ffmpeg', note: 'Bundled and unpacked on first launch' },
  { name: 'aria2', note: 'Bundled on Windows and Linux' },
]

const ICONS = {
  arrow: <path d="M12 4v13m0 0-5-5m5 5 5-5M5 20h14" />,
  bolt: <path d="M13 3 5 13h6l-1 8 8-10h-6l1-8Z" />,
  play: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="3" />
      <path d="m10 9 5 3-5 3V9Z" />
    </>
  ),
  magnet: (
    <path d="M6 3v8a6 6 0 0 0 12 0V3h-4v8a2 2 0 0 1-4 0V3H6Zm0 4h4m4 0h4" />
  ),
  library: (
    <>
      <path d="M4 5h16v4H4zM5 9v10h14V9" />
      <path d="M10 13h4" />
    </>
  ),
  tray: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="3" />
      <path d="M3 8h18M7 6h.01M10 6h.01" />
    </>
  ),
  queue: <path d="M4 6h16M4 12h10M4 18h6m10-6v6m0 0-2.5-2.5M20 18l2.5-2.5" />,
  laptop: (
    <>
      <rect x="4" y="5" width="16" height="11" rx="2" />
      <path d="M2 19h20" />
    </>
  ),
  window: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M12 4v16M3 12h18" />
    </>
  ),
  terminal: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="m7 9 3 3-3 3m5 0h5" />
    </>
  ),
  github: (
    <path d="M9 19c-4 1.5-4-2-6-2.5m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12 12 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V22" />
  ),
}

function Icon({ name, size = 20 }) {
  return (
    <svg
      className="icon"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {ICONS[name]}
    </svg>
  )
}

function detectPlatform() {
  const ua = navigator.userAgent
  return PLATFORMS.find((p) => p.match.test(ua)) || PLATFORMS[0]
}

// Fades sections in as they scroll into view.
function useReveal() {
  useEffect(() => {
    if (!('IntersectionObserver' in window)) return
    const els = document.querySelectorAll('.reveal')
    document.documentElement.classList.add('reveal-ready')
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add('is-visible')
            io.unobserve(e.target)
          }
        }
      },
      { rootMargin: '0px 0px -10% 0px' },
    )
    els.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])
}

function Nav() {
  return (
    <header className="nav-wrap">
      <div className="nav">
        <a className="brand" href="#top">
          <img src="./favicon.png" alt="" width="22" height="22" />
          <span>ZON</span>
        </a>
        <nav>
          <a href="#features">Features</a>
          <a href="#tour">Tour</a>
          <a href="#download">Download</a>
          <a href={REPO} className="nav-gh" aria-label="GitHub">
            <Icon name="github" size={18} />
          </a>
        </nav>
      </div>
    </header>
  )
}

function Hero() {
  const current = detectPlatform()
  return (
    <section className="hero" id="top">
      <div className="hero-grid" aria-hidden="true" />
      <div className="hero-inner">
        <a className="pill" href={RELEASES}>
          <span className="pill-dot" />
          Now on macOS, Windows &amp; Linux
          <span className="pill-arrow">→</span>
        </a>
        <h1>
          The download
          <br />
          <span className="dim">manager.</span>
        </h1>
        <p className="lede">
          Segmented HTTP downloads, video and audio, and torrents — one quiet
          desktop app that picks up where it left off.
        </p>
        <div className="actions">
          <a className="btn btn-solid" href={RELEASES}>
            <Icon name="arrow" size={18} />
            Download for {current.name}
          </a>
          <a className="btn" href={REPO}>
            <Icon name="github" size={18} />
            View source
          </a>
        </div>
        <p className="meta">Free and open source · Built with Flutter</p>
      </div>

      <figure className="shot">
        <div className="shot-frame">
          <div className="shot-bar" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <img
            src="./screenshot.jpg"
            alt="ZON on macOS: the download list with completed files, a speed graph and the details panel"
            width="1920"
            height="1200"
          />
        </div>
      </figure>
    </section>
  )
}

function Sources() {
  const items = [...SOURCES, ...SOURCES]
  return (
    <section className="sources" aria-label="Supported sources">
      <p className="eyebrow center">Paste a link from</p>
      <div className="marquee">
        <ul>
          {items.map((s, i) => (
            <li key={i} aria-hidden={i >= SOURCES.length}>
              {s}
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function Stats() {
  return (
    <section className="stats reveal">
      {STATS.map((s) => (
        <div className="stat" key={s.label}>
          <span className="stat-value">{s.value}</span>
          <span className="stat-label">{s.label}</span>
        </div>
      ))}
    </section>
  )
}

function Segments() {
  // Each lane is one byte range; staggered timings make them finish unevenly.
  const lanes = Array.from({ length: 8 }, (_, i) => ({
    duration: 2.6 + ((i * 7) % 5) * 0.45,
    delay: ((i * 3) % 4) * 0.15,
  }))
  return (
    <div className="segments" aria-hidden="true">
      {lanes.map((l, i) => (
        <div className="lane" key={i}>
          <span className="lane-id">{String(i + 1).padStart(2, '0')}</span>
          <span className="lane-track">
            <span
              className="lane-fill"
              style={{
                animationDuration: `${l.duration}s`,
                animationDelay: `${l.delay}s`,
              }}
            />
          </span>
        </div>
      ))}
    </div>
  )
}

function Features() {
  return (
    <section className="section" id="features">
      <div className="section-head reveal">
        <p className="eyebrow">Features</p>
        <h2>Everything a download manager should do.</h2>
        <p className="section-sub">
          Three engines behind one queue. Every transfer survives a pause, a
          quit or a crash.
        </p>
      </div>

      <div className="bento">
        <article className="card card-wide reveal">
          <div className="card-text">
            <Icon name="bolt" />
            <h3>Segmented HTTP engine</h3>
            <p>
              Splits files into up to 32 parallel byte ranges. Resumes after a
              pause, quit or crash, retries with backoff, and steps aside when a
              server answers 429.
            </p>
          </div>
          <Segments />
        </article>

        <article className="card reveal">
          <Icon name="play" />
          <h3>Video &amp; audio</h3>
          <p>
            YouTube, Shorts, playlists, Instagram, TikTok, X, Vimeo, SoundCloud
            and 1000+ more sites via yt-dlp.
          </p>
          <ul className="chips">
            {FORMATS.map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        </article>

        <article className="card reveal">
          <Icon name="magnet" />
          <h3>BitTorrent</h3>
          <p>
            Magnet links and .torrent files through a private aria2 daemon: live
            peers, pause and resume with piece verification, optional seeding to
            a ratio.
          </p>
          <code className="magnet">magnet:?xt=urn:btih:…</code>
        </article>

        {SMALL_FEATURES.map((f) => (
          <article className="card card-third reveal" key={f.title}>
            <Icon name={f.icon} />
            <h3>{f.title}</h3>
            <p>{f.body}</p>
          </article>
        ))}
      </div>
    </section>
  )
}

function Tour() {
  return (
    <section className="section" id="tour">
      <div className="section-head reveal">
        <p className="eyebrow">A closer look</p>
        <h2>Built to stay out of your way.</h2>
      </div>

      <div className="tour-row reveal">
        <div className="tour-text">
          <span className="tour-num">01</span>
          <h3>Paste anything.</h3>
          <p>
            A plain URL, a playlist, a magnet link or a whole list of links. ZON
            picks the right engine, so you never choose between three apps.
          </p>
        </div>
        <div className="tour-media">
          <img
            src="./shot-input.jpg"
            alt="The ZON link bar with shortcuts for clipboard, multiple links, YouTube, torrents and batch downloads"
            width="1200"
            height="193"
            loading="lazy"
          />
        </div>
      </div>

      <div className="tour-row tour-row-flip reveal">
        <div className="tour-text">
          <span className="tour-num">02</span>
          <h3>Every detail, one click away.</h3>
          <p>
            Progress, connection count, HTTP status, server and resume support
            for every transfer — in a side panel instead of a log file.
          </p>
        </div>
        <div className="tour-media tour-media-tall">
          <img
            src="./shot-details.jpg"
            alt="The ZON details panel showing a completed download at 100% with 16 connections"
            width="670"
            height="720"
            loading="lazy"
          />
        </div>
      </div>
    </section>
  )
}

function Tools() {
  return (
    <section className="section">
      <div className="section-head reveal">
        <p className="eyebrow">Under the hood</p>
        <h2>No dependencies to hunt down.</h2>
      </div>
      <ul className="tools reveal">
        {TOOLS.map((t) => (
          <li key={t.name}>
            <code>{t.name}</code>
            <span>{t.note}</span>
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
      <div className="section-head reveal">
        <p className="eyebrow">Download</p>
        <h2>Pick your platform.</h2>
      </div>
      <ul className="platforms reveal">
        {PLATFORMS.map((p) => {
          const isCurrent = p.id === current.id
          return (
            <li key={p.id} className={isCurrent ? 'platform is-current' : 'platform'}>
              <div className="platform-top">
                <Icon name={p.icon} size={28} />
                {isCurrent && <span className="tag">Your system</span>}
              </div>
              <h3>{p.name}</h3>
              <p className="platform-detail">{p.detail}</p>
              <code className="platform-file">{p.file}</code>
              <a
                className={isCurrent ? 'btn btn-solid btn-block' : 'btn btn-block'}
                href={RELEASES}
              >
                <Icon name="arrow" size={16} />
                Download
              </a>
            </li>
          )
        })}
      </ul>
      <p className="note">
        Every build is also on <a href={`${REPO}/releases`}>GitHub Releases</a>.
        Source and CI live in <a href={REPO}>the repository</a>.
      </p>
    </section>
  )
}

function Cta() {
  const current = detectPlatform()
  return (
    <section className="cta reveal">
      <img src="./favicon.png" alt="" width="56" height="56" />
      <h2>Stop babysitting downloads.</h2>
      <p>It's free, it's open source, and it picks up where it left off.</p>
      <a className="btn btn-solid" href={RELEASES}>
        <Icon name="arrow" size={18} />
        Download for {current.name}
      </a>
    </section>
  )
}

function Footer() {
  return (
    <footer className="footer">
      <div className="footer-brand">
        <img src="./favicon.png" alt="" width="18" height="18" />
        <span>ZON</span>
      </div>
      <p className="footer-legal">
        Only download content you have the right to download.
      </p>
      <p className="footer-links">
        <a href={REPO}>GitHub</a>
        <a href={`${REPO}/releases`}>Releases</a>
        <a href={`${REPO}/issues`}>Issues</a>
      </p>
    </footer>
  )
}

export default function App() {
  useReveal()
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Sources />
        <Stats />
        <Features />
        <Tour />
        <Tools />
        <Download />
        <Cta />
      </main>
      <Footer />
    </>
  )
}
