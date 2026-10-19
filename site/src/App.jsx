import { useEffect, useState } from 'react'

const RELEASES = 'https://github.com/txngerine/zon/releases/latest'
const REPO = 'https://github.com/txngerine/zon'

const PLATFORMS = [
  {
    id: 'macos',
    name: 'macOS',
    detail: 'Apple Silicon',
    file: 'zon-macos-arm64.zip',
    match: /Mac/,
    icon: 'apple',
    note: 'Unzip and drag ZON to Applications.',
  },
  {
    id: 'windows',
    name: 'Windows',
    detail: 'x64 · installer',
    file: 'zon-windows-x64-setup.exe',
    match: /Win/,
    icon: 'window',
    note: 'Per-user install, no admin rights needed.',
  },
  {
    id: 'linux',
    name: 'Linux',
    detail: 'x64 · tarball',
    file: 'zon-linux-x64.tar.gz',
    match: /Linux|X11/,
    icon: 'terminal',
    note: 'Needs GTK 3 for the tray icon.',
  },
]

const SOURCES = [
  'YouTube',
  'Shorts',
  'Playlists',
  'Instagram Reels',
  'TikTok',
  'X',
  'Facebook',
  'Vimeo',
  'SoundCloud',
  'Twitch',
  'Reddit',
  'Magnet links',
  '.torrent',
  'HTTP / HTTPS',
]

const STATS = [
  { value: '32', label: 'parallel connections per file' },
  { value: '1000+', label: 'video and audio sites' },
  { value: '3', label: 'desktop platforms' },
  { value: '$0', label: 'free and open source' },
]

const FORMATS = ['Best', '4K', '1080p', '720p', '480p', 'MP3 320', 'M4A']

const EXTRAS = [
  {
    icon: 'library',
    title: 'Survives anything',
    body: 'Your library lives in one JSON file. Quit, crash or reboot mid-transfer and everything re-queues on the next launch.',
  },
  {
    icon: 'bookmark',
    title: 'Browser button',
    body: 'A bookmarklet sends the page you are on to ZON — or straight to MP3. It talks to 127.0.0.1 only, with a per-install key.',
  },
  {
    icon: 'tray',
    title: 'Lives in the tray',
    body: 'Pause and resume from the menu bar, native notifications, launch at login, and a banner when you copy a link.',
  },
  {
    icon: 'queue',
    title: 'Queue control',
    body: 'Priorities, drag-to-reorder, a cap on simultaneous downloads, and speed limits globally or per download.',
  },
  {
    icon: 'drop',
    title: 'Drag & drop',
    body: 'Drop links, .torrent files, or .txt / .webloc / .url files anywhere on the window to queue them.',
  },
  {
    icon: 'lock',
    title: 'Logged-in sites',
    body: 'Private, age-restricted or Instagram videos? Pick your browser and yt-dlp reads its cookies — nothing is uploaded.',
  },
]

const TOOLS = [
  { name: 'yt-dlp', role: 'Video & audio', note: 'One-click install from Settings › Media' },
  { name: 'ffmpeg', role: 'Merging & MP3', note: 'Bundled, unpacked on first launch' },
  { name: 'aria2', role: 'BitTorrent', note: 'Bundled on Windows and Linux' },
]

const FAQ = [
  {
    q: 'Is ZON really free?',
    a: 'Yes. ZON is open source, with no account to create and no ads. The source and every release build are on GitHub.',
  },
  {
    q: 'Do I need to install anything else?',
    a: 'ffmpeg ships inside the app, and aria2 does too on Windows and Linux. For video sites, ZON installs yt-dlp for you in one click. Anything already on your PATH or from Homebrew, WinGet or Scoop is picked up automatically.',
  },
  {
    q: 'What happens if my Mac sleeps or the app crashes?',
    a: 'HTTP downloads resume from the exact byte where each segment stopped, torrents re-verify their pieces, and anything that was running is put back in the queue when ZON starts again.',
  },
  {
    q: 'Where is my data stored?',
    a: 'Only on your machine: downloads, history and settings are in library.json in the app-support folder. The browser button listens on 127.0.0.1 and nothing else.',
  },
  {
    q: 'Can I download anything I want?',
    a: 'Only download content you have the right to download. Many sites restrict downloading in their terms, and copyright law still applies.',
  },
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
  bookmark: <path d="M6 4h12v16l-6-4-6 4V4Z" />,
  drop: (
    <>
      <path d="M12 3v12m0 0-4-4m4 4 4-4" />
      <path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" />
    </>
  ),
  lock: (
    <>
      <rect x="5" y="11" width="14" height="10" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </>
  ),
  history: (
    <>
      <path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
      <path d="M3 3v5h5M12 7v5l3 2" />
    </>
  ),
  apple: (
    <path d="M16 13.5c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9s-1.9-.8-3.1-.8C6.4 8.2 5 9.1 4.2 10.5c-1.7 2.9-.4 7.2 1.2 9.6.8 1.1 1.7 2.4 3 2.4 1.2-.1 1.6-.8 3.1-.8s1.8.8 3.1.8c1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7 0 0-2.6-1-2.8-4ZM13.7 6.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4Z" />
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
  check: <path d="m5 12 5 5 9-10" />,
  plus: <path d="M12 5v14M5 12h14" />,
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

// A screenshot in a macOS-style window frame.
function Window({ src, alt, width, height, title, eager, className = '' }) {
  return (
    <div className={`window ${className}`}>
      <div className="window-bar" aria-hidden="true">
        <span />
        <span />
        <span />
        {title && <em>{title}</em>}
      </div>
      <img
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading={eager ? 'eager' : 'lazy'}
        decoding="async"
      />
    </div>
  )
}

// A cropped piece of the UI, without window chrome.
function Panel({ src, alt, width, height, className = '' }) {
  return (
    <div className={`panel ${className}`}>
      <img src={src} alt={alt} width={width} height={height} loading="lazy" decoding="async" />
    </div>
  )
}

function Nav() {
  return (
    <header className="nav-wrap">
      <div className="nav">
        <a className="brand" href="#top">
          <img src="./logo.svg" alt="" width="26" height="26" />
          <span>ZON</span>
        </a>
        <nav>
          <a href="#features">Features</a>
          <a href="#themes">Themes</a>
          <a href="#faq">FAQ</a>
          <a href={REPO} className="nav-gh" aria-label="GitHub">
            <Icon name="github" size={18} />
          </a>
          <a href="#download" className="nav-cta">
            Download
          </a>
        </nav>
      </div>
    </header>
  )
}

function Hero({ platform }) {
  return (
    <section className="hero" id="top">
      <div className="hero-glow" aria-hidden="true" />
      <div className="hero-grid" aria-hidden="true" />
      <div className="hero-inner">
        <a className="pill" href={RELEASES}>
          <span className="pill-dot" />
          v1.0 — now with a Windows installer
          <span className="pill-arrow">→</span>
        </a>
        <h1>
          Every download.
          <br />
          <span className="dim">One quiet app.</span>
        </h1>
        <p className="lede">
          Files, YouTube and 1000+ video sites, and torrents — split into
          parallel connections, resumed after any crash, and kept in one tidy
          library.
        </p>
        <div className="actions">
          <a className="btn btn-solid btn-lg" href={RELEASES}>
            <Icon name="arrow" size={18} />
            Download for {platform.name}
          </a>
          <a className="btn btn-lg" href={REPO}>
            <Icon name="github" size={18} />
            Star on GitHub
          </a>
        </div>
        <p className="meta">
          Free &amp; open source · macOS · Windows · Linux
        </p>
      </div>

      <figure className="hero-shot">
        <Window
          src="./shots/dashboard-dark.webp"
          alt="ZON on macOS downloading an Ubuntu ISO over 32 connections, a 4K YouTube video and an Arch Linux torrent, with a live speed graph and the details panel"
          width="2400"
          height="1500"
          title="ZON"
          eager
        />
        <Callout className="callout-a" label="Live throughput" value="39.3 MB/s" />
        <Callout className="callout-b" label="Ubuntu ISO" value="32 connections" />
        <Callout className="callout-c" label="Torrent swarm" value="212 seeds" />
      </figure>
    </section>
  )
}

function Callout({ label, value, className }) {
  return (
    <div className={`callout ${className}`} aria-hidden="true">
      <span className="callout-dot" />
      <span className="callout-label">{label}</span>
      <span className="callout-value">{value}</span>
    </div>
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

function Bullets({ items }) {
  return (
    <ul className="bullets">
      {items.map((b) => (
        <li key={b}>
          <Icon name="check" size={16} />
          {b}
        </li>
      ))}
    </ul>
  )
}

function Features() {
  return (
    <section className="section" id="features">
      <div className="section-head reveal">
        <p className="eyebrow">Features</p>
        <h2>Three engines. One queue.</h2>
        <p className="section-sub">
          Paste anything — a file URL, a YouTube playlist, a magnet link — and
          ZON picks the right engine. No juggling three apps.
        </p>
      </div>

      <article className="feature feature-speed reveal">
        <div className="feature-text">
          <span className="feature-tag">
            <Icon name="bolt" size={16} /> Segmented HTTP
          </span>
          <h3>Saturates your connection, not your patience.</h3>
          <p>
            Every file is split into up to 32 byte ranges fetched in parallel.
            Pause, quit or crash — each segment resumes from its exact byte. A
            server that answers 429 gets backed off automatically instead of
            hammered.
          </p>
          <Bullets
            items={[
              'Up to 32 connections per file',
              'Resume after pause, quit or crash',
              'Retries with backoff, honours 429',
            ]}
          />
        </div>
        <div className="feature-media">
          <Panel
            src="./shots/speed.webp"
            alt="ZON's download speed panel: 39.3 MB/s live, 50.8 MB/s peak, 40.9 MB/s average"
            width="1400"
            height="247"
          />
          <Segments />
        </div>
      </article>

      <article className="feature feature-flip reveal">
        <div className="feature-text">
          <span className="feature-tag">
            <Icon name="play" size={16} /> Video &amp; audio
          </span>
          <h3>YouTube, Reels, TikTok — and 1000+ more.</h3>
          <p>
            Paste a link and ZON shows the title, length and size before you
            commit. Pick a resolution or pull just the audio. Playlists and
            channels become one download per video.
          </p>
          <ul className="chips">
            {FORMATS.map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        </div>
        <div className="feature-media">
          <Panel
            className="panel-tall"
            src="./shots/media.webp"
            alt="The Download Video or Audio dialog with a YouTube link, a preview of the video, and format choices from Best video and 4K to MP3 and M4A"
            width="1156"
            height="1430"
          />
        </div>
      </article>

      <article className="feature reveal">
        <div className="feature-text">
          <span className="feature-tag">
            <Icon name="magnet" size={16} /> BitTorrent
          </span>
          <h3>Torrents without another client.</h3>
          <p>
            Magnet links and .torrent files — from a URL, the file picker, drag
            &amp; drop or Finder's “Open With” — run through a private aria2
            daemon. Watch peers, seeds and upload live, and seed back to a ratio
            if you like.
          </p>
          <Bullets
            items={[
              'Pause and resume with piece verification',
              'Stalled torrents free their download slot',
              'Optional system handler for magnet links',
            ]}
          />
        </div>
        <div className="feature-media feature-media-narrow">
          <Panel
            className="panel-tall"
            src="./shots/torrent.webp"
            alt="The details panel for an Arch Linux torrent at 86%: 48 peers, 212 seeds, 940 KB/s upload"
            width="680"
            height="1665"
          />
        </div>
      </article>

      <div className="duo reveal">
        <figure>
          <Panel
            src="./shots/history.webp"
            alt="ZON's history screen listing completed, failed and cancelled downloads with filters and search"
            width="1400"
            height="1384"
          />
          <figcaption>
            <Icon name="history" size={16} />
            <span>
              <strong>History</strong> — every finished, failed and cancelled
              transfer, searchable, one click to re-download.
            </span>
          </figcaption>
        </figure>
        <figure>
          <Panel
            src="./shots/settings.webp"
            alt="ZON's settings: download location, startup and tray options, simultaneous downloads, connections per download, speed limit and retries"
            width="1400"
            height="1384"
          />
          <figcaption>
            <Icon name="queue" size={16} />
            <span>
              <strong>Settings</strong> — connections, retries, speed limits,
              proxy, notifications and media defaults.
            </span>
          </figcaption>
        </figure>
      </div>
    </section>
  )
}

function Themes() {
  const [split, setSplit] = useState(50)
  return (
    <section className="section" id="themes">
      <div className="section-head reveal">
        <p className="eyebrow">Light &amp; dark</p>
        <h2>Matches your desktop.</h2>
        <p className="section-sub">
          Follows the system theme or pick one. Drag to compare.
        </p>
      </div>
      <div className="compare reveal" style={{ '--split': `${split}%` }}>
        <Window
          className="window-light"
          src="./shots/dashboard-light.webp"
          alt="ZON in light mode"
          width="2400"
          height="1500"
        />
        <div className="compare-top" aria-hidden="true">
          <Window
            src="./shots/dashboard-dark.webp"
            alt=""
            width="2400"
            height="1500"
          />
        </div>
        <span className="compare-label compare-label-dark" aria-hidden="true">
          Dark
        </span>
        <span className="compare-label compare-label-light" aria-hidden="true">
          Light
        </span>
        <div className="compare-handle" aria-hidden="true">
          <span />
        </div>
        <input
          type="range"
          min="0"
          max="100"
          value={split}
          onChange={(e) => setSplit(Number(e.target.value))}
          aria-label="Compare dark and light themes"
        />
      </div>
    </section>
  )
}

function Extras() {
  return (
    <section className="section">
      <div className="section-head reveal">
        <p className="eyebrow">The details</p>
        <h2>Small things, done properly.</h2>
      </div>
      <div className="extras">
        {EXTRAS.map((f) => (
          <article className="card reveal" key={f.title}>
            <span className="card-icon">
              <Icon name={f.icon} />
            </span>
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
      <div className="tools-wrap reveal">
        <div className="tools-head">
          <p className="eyebrow">Under the hood</p>
          <h2>No dependencies to hunt down.</h2>
          <p className="section-sub">
            ZON runs proven open-source tools as separate programs and sets
            them up for you. Anything already on your PATH is used first.
          </p>
        </div>
        <ul className="tools">
          {TOOLS.map((t) => (
            <li key={t.name}>
              <code>{t.name}</code>
              <span className="tool-role">{t.role}</span>
              <span className="tool-note">{t.note}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function Download({ platform }) {
  return (
    <section className="section" id="download">
      <div className="section-head reveal">
        <p className="eyebrow">Download</p>
        <h2>Pick your platform.</h2>
        <p className="section-sub">Built and tested by CI on every release.</p>
      </div>
      <ul className="platforms reveal">
        {PLATFORMS.map((p) => {
          const isCurrent = p.id === platform.id
          return (
            <li key={p.id} className={isCurrent ? 'platform is-current' : 'platform'}>
              <div className="platform-top">
                <Icon name={p.icon} size={28} />
                {isCurrent && <span className="tag">Your system</span>}
              </div>
              <h3>{p.name}</h3>
              <p className="platform-detail">{p.detail}</p>
              <code className="platform-file">{p.file}</code>
              <p className="platform-note">{p.note}</p>
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
        Also available as a portable Windows zip on{' '}
        <a href={`${REPO}/releases`}>GitHub Releases</a>. Prefer to build it
        yourself? <a href={REPO}>Clone the repository</a>.
      </p>
    </section>
  )
}

function Faq() {
  return (
    <section className="section" id="faq">
      <div className="section-head reveal">
        <p className="eyebrow">FAQ</p>
        <h2>Questions, answered.</h2>
      </div>
      <div className="faq reveal">
        {FAQ.map((f) => (
          <details key={f.q}>
            <summary>
              {f.q}
              <Icon name="plus" size={18} />
            </summary>
            <p>{f.a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}

function Cta({ platform }) {
  return (
    <section className="cta reveal">
      <img src="./logo.svg" alt="" width="80" height="80" />
      <h2>Stop babysitting downloads.</h2>
      <p>Free, open source, and it picks up exactly where it left off.</p>
      <a className="btn btn-solid btn-lg" href={RELEASES}>
        <Icon name="arrow" size={18} />
        Download for {platform.name}
      </a>
    </section>
  )
}

function Footer() {
  return (
    <footer className="footer">
      <div className="footer-brand">
        <img src="./logo.svg" alt="" width="20" height="20" />
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
  const platform = detectPlatform()
  return (
    <>
      <Nav />
      <main>
        <Hero platform={platform} />
        <Sources />
        <Stats />
        <Features />
        <Themes />
        <Extras />
        <Tools />
        <Download platform={platform} />
        <Faq />
        <Cta platform={platform} />
      </main>
      <Footer />
    </>
  )
}
