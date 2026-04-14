import { useEffect, useMemo, useRef, useState } from "react";

const productTour = [
  {
    kicker: "Overview",
    title: "One home health score with the next actions already prioritized.",
    text: "See due soon, overdue, and completed maintenance in one calm dashboard."
  },
  {
    kicker: "Systems",
    title: "Track all of your appliances in one place.",
    text: "From HVAC and water heaters to kitchen, laundry, and safety systems, each one gets health context, metadata, and service history."
  },
  {
    kicker: "Tasks",
    title: "Recurring maintenance that actually stays on schedule.",
    text: "Tasks are grouped by urgency: Overdue, Today, Upcoming, Planned, Completed."
  },
  {
    kicker: "AI Setup",
    title: "Add a system in under a minute with AI-assisted setup.",
    text: "Use a photo and model hint, then review and approve suggested tasks before saving."
  }
];

const faqItems = [
  {
    q: "Can I use Domo without AI?",
    a: "Yes. Manual setup works end-to-end. AI is optional acceleration."
  },
  {
    q: "Does AI auto-change my home data?",
    a: "No. Suggestions are always review-before-save."
  },
  {
    q: "Where do API keys live?",
    a: "Not in the app source. Production setup uses secure backend/keychain handling."
  },
  {
    q: "Who is this for?",
    a: "Homeowners, busy families, and property operators who want fewer surprise breakdowns."
  }
];

const multiDeviceScreens = [
  {
    id: "left",
    label: "Choose System",
    media: "video",
    step: "1",
    subtext: "Choose your system type"
  },
  {
    id: "center",
    label: "Selecting Tasks 2",
    media: "video2",
    step: "2",
    subtext: "Select recommended recurring tasks"
  },
  {
    id: "right",
    label: "Actual System",
    media: "video3",
    step: "3",
    subtext: "Review and save the full system profile"
  }
];

export default function App() {
  const [isLoaded, setIsLoaded] = useState(false);
  const [domoOn, setDomoOn] = useState(false);
  const [activeOutcome, setActiveOutcome] = useState("without");
  const [activeVideoId, setActiveVideoId] = useState(null);
  const outcomeRefs = useRef({});
  const stageRef = useRef(null);
  const videoRefs = useRef({});
  const sequenceTimerRef = useRef(null);
  const hasStartedSequenceRef = useRef(false);
  const videoOrder = useMemo(
    () =>
      multiDeviceScreens
        .filter((screen) => screen.media?.startsWith("video"))
        .map((screen) => screen.id),
    []
  );

  const playVideoById = (id) => {
    const target = videoRefs.current[id];
    if (!target) {
      return;
    }

    Object.entries(videoRefs.current).forEach(([videoId, video]) => {
      if (!video) return;
      if (videoId !== id) {
        video.pause();
        video.currentTime = 0;
      }
    });

    target.currentTime = 0;
    target.defaultPlaybackRate = 0.8;
    target.playbackRate = 0.8;
    setActiveVideoId(id);
    target.play().catch(() => {});
  };

  const handleVideoEnded = (id) => {
    const index = videoOrder.indexOf(id);
    if (index < 0) return;
    const nextId = videoOrder[index + 1] ?? videoOrder[0];

    clearTimeout(sequenceTimerRef.current);
    sequenceTimerRef.current = setTimeout(() => {
      playVideoById(nextId);
    }, 450);
  };

  useEffect(() => {
    let timer;
    const frame = requestAnimationFrame(() => {
      timer = setTimeout(() => setIsLoaded(true), 40);
    });

    return () => {
      cancelAnimationFrame(frame);
      clearTimeout(timer);
    };
  }, []);

  useEffect(() => {
    if (!isLoaded) {
      return;
    }

    const powerOnTimer = setTimeout(() => {
      setDomoOn(true);
    }, 950);

    return () => clearTimeout(powerOnTimer);
  }, [isLoaded]);

  useEffect(() => {
    if (!isLoaded || !stageRef.current || hasStartedSequenceRef.current) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        const [entry] = entries;
        if (!entry?.isIntersecting || hasStartedSequenceRef.current) return;

        hasStartedSequenceRef.current = true;
        clearTimeout(sequenceTimerRef.current);
        sequenceTimerRef.current = setTimeout(() => {
          playVideoById(videoOrder[0]);
        }, 300);
      },
      { threshold: 0.45 }
    );

    observer.observe(stageRef.current);

    return () => {
      observer.disconnect();
    };
  }, [isLoaded, videoOrder]);

  useEffect(() => {
    return () => {
      clearTimeout(sequenceTimerRef.current);
      Object.values(videoRefs.current).forEach((video) => {
        if (!video) return;
        video.pause();
      });
    };
  }, []);

  useEffect(() => {
    const withoutPanel = outcomeRefs.current.without;
    const withPanel = outcomeRefs.current.with;
    if (!withoutPanel || !withPanel) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          if (entry.target === withoutPanel) {
            setActiveOutcome("without");
          }
          if (entry.target === withPanel) {
            setActiveOutcome("with");
          }
        });
      },
      { threshold: 0.6, rootMargin: "-15% 0px -20% 0px" }
    );

    observer.observe(withoutPanel);
    observer.observe(withPanel);

    return () => observer.disconnect();
  }, []);

  return (
    <div className={`page ${isLoaded ? "is-loaded" : ""}`}>
      <div className="page-veil" aria-hidden />
      <div className="wrap">
        <header className="nav reveal">
          <div className="brand">
            <img src="/assets/domo-logo-updated.png" alt="Domo logo" />
            DOMO
          </div>
          <a href="#pricing">View Pricing</a>
        </header>

        <section className="hero">
          <div className="hero-layout">
            <div className="hero-copy">
              <p className="kicker reveal">Home maintence, Simplified</p>
              <h1 className="reveal d2">Protect every home system without the chaos.</h1>
              <p className="reveal d3">
                Domo is a premium home maintenance app for Apple platforms. Track systems,
                automate recurring care, and use AI to set everything up in minutes.
              </p>
              <div className="cta reveal d4">
                <a className="btn btn-dark" href="#download">Download for iPhone</a>
                <a className="btn btn-light" href="#pricing">View Pricing</a>
              </div>
              <div className="proof-strip reveal d4">
                <span>Setup in under 60 seconds</span>
                <span>Review-before-save AI</span>
                <span>Built for iOS + macOS</span>
              </div>
            </div>

            <aside className="hero-media hero-media-soft" aria-label="Domo iPhone app preview">
              <img
                src="/assets/iphone-17-pro-deep-blue.png"
                alt="iPhone 17 Pro Deep Blue mockup"
                className="hero-angled-phone"
              />
            </aside>
          </div>
        </section>

        <section className="problem-outcome problem-outcome-scroll reveal d2">
          <article
            className={`panel dark outcome-panel ${activeOutcome === "without" ? "is-active" : ""}`}
            ref={(node) => {
              outcomeRefs.current.without = node;
            }}
          >
            <p className="kicker">Without Domo</p>
            <h2>Maintenance lives in notes, texts, and memory.</h2>
            <p>
              Most people miss filters, inspections, and service intervals until something
              breaks and costs spike.
            </p>
          </article>
          <article
            className={`panel outcome-panel ${activeOutcome === "with" ? "is-active" : ""}`}
            ref={(node) => {
              outcomeRefs.current.with = node;
            }}
          >
            <p className="kicker">With Domo</p>
            <h2>One health score. Clear priorities. Fewer surprise failures.</h2>
            <p>
              Domo keeps every recurring task visible by urgency so you always know what to
              handle next.
            </p>
            <div className="domo-power-row">
              <button
                type="button"
                className={`power-toggle ${domoOn ? "is-on" : ""}`}
                aria-pressed={domoOn}
                onClick={() => setDomoOn((value) => !value)}
              >
                <span className="power-toggle-track">
                  <span className="power-toggle-thumb" />
                </span>
                <span className="power-toggle-label">{domoOn ? "Domo On" : "Domo Off"}</span>
              </button>
              <div className={`domo-signal ${domoOn ? "is-on" : ""}`}>
                <img src="/assets/domo-logo-updated.png" alt="Domo activation logo" />
              </div>
            </div>
          </article>
        </section>

        <section className="tour-grid">
          {productTour.map((item, idx) => (
            <article className={`card reveal d${Math.min(idx + 1, 4)}`} key={item.title}>
              <p className="kicker">{item.kicker}</p>
              <h3>{item.title}</h3>
              <p>{item.text}</p>
            </article>
          ))}
        </section>

        <section className="multi-device-showcase reveal d3">
          <div className="section-head">
            <p className="kicker">Flow Preview</p>
            <h2 className="multi-device-title">Set up any home system in under a minute.</h2>
          </div>
          <div
            className="multi-device-stage"
            aria-label="Three iPhone flow mockups"
            ref={stageRef}
          >
            <div className="multi-device-glow" />
            <div className="multi-device-row">
              {multiDeviceScreens.map((screen, idx) => (
                <article
                  className={`phone-mock phone-${screen.id} ${
                    screen.media?.startsWith("video") ? "has-video" : ""
                  } ${activeVideoId === screen.id ? "is-playing" : ""} reveal d${Math.min(
                    idx + 1,
                    4
                  )}`}
                  key={screen.id}
                  aria-label={screen.label}
                >
                  <div className="phone-caption">
                    <span className="phone-step-tag">{screen.step}</span>
                    <p>{screen.subtext}</p>
                  </div>
                  <div className="phone-screen">
                    {screen.media === "video" ||
                    screen.media === "video2" ||
                    screen.media === "video3" ? (
                      <video
                        className="phone-screen-media"
                        muted
                        playsInline
                        preload="metadata"
                        ref={(node) => {
                          videoRefs.current[screen.id] = node;
                        }}
                        onLoadedMetadata={(event) => {
                          event.currentTarget.defaultPlaybackRate = 0.8;
                          event.currentTarget.playbackRate = 0.8;
                        }}
                        onEnded={() => handleVideoEnded(screen.id)}
                      >
                        <source
                          src={
                            screen.media === "video"
                              ? "/assets/choose-system.mp4"
                              : screen.media === "video2"
                                ? "/assets/selecting-the-tasks-2.mp4"
                                : "/assets/actual-system.mp4"
                          }
                          type="video/mp4"
                        />
                      </video>
                    ) : (
                      <div
                        className="phone-screen-media phone-screen-image"
                        style={{
                          backgroundImage: "url('/assets/showcase-triple-reference.png')",
                          backgroundPosition: `${screen.posX} center`
                        }}
                      />
                    )}
                  </div>
                  <div className="phone-notch" />
                  <div className="phone-home-indicator" />
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="pricing" className="pricing reveal d2">
          <div className="section-head">
            <p className="kicker">Pricing</p>
            <h2>Start free. Upgrade when your home stack grows.</h2>
          </div>
          <div className="pricing-grid">
            <article className="price-card">
              <p className="kicker">Starter</p>
              <h3>Free</h3>
              <p>1 home, core system tracking, recurring tasks.</p>
              <a className="btn btn-light" href="#download">Get Started</a>
            </article>
            <article className="price-card featured">
              <p className="kicker">Pro</p>
              <h3>$8/mo</h3>
              <p>Unlimited systems, AI recommendations, priority reminders.</p>
              <a className="btn btn-dark" href="#download">Start Pro Trial</a>
            </article>
            <article className="price-card">
              <p className="kicker">Family / Property</p>
              <h3>$19/mo</h3>
              <p>Multiple homes, shared access, advanced maintenance planning.</p>
              <a className="btn btn-light" href="#download">Talk to Us</a>
            </article>
          </div>
        </section>

        <section id="download" className="download reveal d3">
          <div>
            <p className="kicker">Download</p>
            <h2>Get Domo on iPhone today.</h2>
            <p>Also available in prototype form for macOS product testing.</p>
          </div>
          <div className="download-ctas">
            <a className="app-store-badge" href="#" aria-label="Download on the App Store">
              <span className="app-store-apple" aria-hidden></span>
              <span className="app-store-copy">
                <small>Download on the</small>
                <strong>App Store</strong>
              </span>
            </a>
            <a className="btn btn-dark" href="#">Download for iPhone</a>
            <a className="btn btn-light" href="#">Join Early Access</a>
          </div>
        </section>

        <section className="faq reveal d4">
          <div className="section-head">
            <p className="kicker">Trust + FAQ</p>
            <h2>Clear answers before you commit.</h2>
          </div>
          <div className="faq-grid">
            {faqItems.map((item) => (
              <article className="faq-item" key={item.q}>
                <h3>{item.q}</h3>
                <p>{item.a}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="final-cta reveal d4">
          <h2>Stop reacting to home issues. Start staying ahead of them.</h2>
          <a className="btn btn-dark" href="#download">Download Domo</a>
        </section>
      </div>
    </div>
  );
}
