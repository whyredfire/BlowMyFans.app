const modes = [
  { title: "Auto", text: "macOS runs the fans as it always does. Blow My Fans just shows you what's going on." },
  { title: "Manual", text: "One slider for every fan. Its lowest notch stops them while your Mac is idle." },
  {
    title: "Curve",
    text: "The fans follow a curve you draw against CPU temperature. At 0% they stop. It never dips as things heat up, and short spikes don't send the fans surging.",
  },
  { title: "Full Blast", text: "Every fan at maximum, for when you want it cool right now." },
];

export function Modes() {
  return (
    <section id="modes" className="mx-auto max-w-5xl scroll-mt-8 px-6 pt-32">
      <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">Four modes, one click away.</h2>
      <p className="mt-5 max-w-2xl leading-relaxed text-pretty text-neutral-400">
        Look around freely: nothing changes until you press Apply. The first time you apply a mode other than Auto,
        the app asks for your password to install the small helper that sets fan speeds.
      </p>
      <dl className="mt-12 divide-y divide-white/10 border-y border-white/10">
        {modes.map(({ title, text }) => (
          <div key={title} className="grid gap-2 py-5 sm:grid-cols-[10rem_1fr]">
            <dt className="font-medium text-white">{title}</dt>
            <dd className="leading-relaxed text-neutral-400">{text}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
