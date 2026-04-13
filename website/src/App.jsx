const featureCards = [
  {
    title: 'One Home Health Score',
    text: 'Track your entire home with a single score that updates as you complete maintenance and keep systems in peak shape.'
  },
  {
    title: 'Recurring Tasks That Stick',
    text: 'Set tasks once for HVAC, detectors, filters, and appliances. Domo keeps your schedule moving automatically.'
  },
  {
    title: 'System Timelines',
    text: 'See service history by system so you know what was done, when it happened, and what comes next.'
  },
  {
    title: 'Priority Buckets',
    text: 'Overdue, Today, and Upcoming views make it obvious what to do now and what can wait.'
  }
]

const aiCallouts = [
  'AI suggests setup details from model and photo hints',
  'You review and approve suggestions before saving',
  'No surprise auto-actions, your plan stays in your control'
]

const faqs = [
  {
    q: 'Does Domo replace contractors?',
    a: 'No. Domo helps you stay organized and proactive so you can call pros at the right time with better records.'
  },
  {
    q: 'Can I use Domo for condos or rentals?',
    a: 'Yes. You can track the systems that matter in any home type and customize tasks by property.'
  },
  {
    q: 'What happens to my data?',
    a: 'Your maintenance data is tied to your account and visible in-app. AI setup is assistive only and review-first.'
  }
]

export default function App() {
  return (
    <div className="page">
      <header className="header">
        <div className="brand">
          <img src="/assets/domo-logo.png" alt="Domo logo" />
          <span>Domo</span>
        </div>
        <button className="pill">Get Early Access</button>
      </header>

      <section className="hero">
        <p className="kicker">Home maintenance, simplified</p>
        <h1>Stay ahead of repairs with one calm, modern dashboard.</h1>
        <p>
          Domo gives homeowners a clear plan to protect every major system, reduce surprise repairs,
          and keep maintenance on schedule without the stress.
        </p>
        <div className="actions">
          <button className="primary">Start Free</button>
          <button className="secondary">See Demo</button>
        </div>
      </section>

      <section className="stats">
        <div><strong>92%</strong><span>Tasks completed on time</span></div>
        <div><strong>6 min</strong><span>Average setup time</span></div>
        <div><strong>18k+</strong><span>Homes using Domo</span></div>
      </section>

      <section className="section">
        <div className="section-head">
          <h2>Feature callouts built for real homes</h2>
          <p>Everything is designed to keep you proactive, not overwhelmed.</p>
        </div>
        <div className="feature-grid">
          {featureCards.map((item) => (
            <article key={item.title} className="card">
              <h3>{item.title}</h3>
              <p>{item.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="section ai-band">
        <div>
          <p className="kicker">AI you can trust</p>
          <h2>AI-assisted setup with human approval</h2>
          <p>
            Domo uses AI to speed up setup, not to take over decisions. You always review
            recommended systems and recurring tasks before they are saved.
          </p>
        </div>
        <ul>
          {aiCallouts.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </section>

      <section className="section outcomes">
        <h2>Before Domo vs After Domo</h2>
        <div className="compare-grid">
          <article className="card bad">
            <h3>Without Domo</h3>
            <p>Missed service windows, reactive repairs, and no clear picture of what needs attention.</p>
          </article>
          <article className="card good">
            <h3>With Domo</h3>
            <p>Predictable upkeep, fewer emergencies, and a reliable weekly plan for your entire home.</p>
          </article>
        </div>
      </section>

      <section className="section testimonial">
        <h2>What early users say</h2>
        <blockquote>
          "Domo finally made home maintenance feel manageable. We know exactly what to do each week
          and our home health score keeps us accountable."
        </blockquote>
        <p className="quote-credit">Maya R., homeowner</p>
      </section>

      <section className="section cta-block">
        <h2>Ready to protect your home proactively?</h2>
        <p>Join early access and build your maintenance plan in minutes.</p>
        <button className="primary">Reserve Your Spot</button>
      </section>

      <section className="section faq">
        <h2>FAQ</h2>
        <div className="faq-list">
          {faqs.map((item) => (
            <article key={item.q} className="card">
              <h3>{item.q}</h3>
              <p>{item.a}</p>
            </article>
          ))}
        </div>
      </section>
    </div>
  )
}
