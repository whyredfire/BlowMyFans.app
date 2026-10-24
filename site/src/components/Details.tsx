const details = [
  { title: "Every sensor", text: "CPU, GPU, SSD, battery and more, named for your Mac's model. Keep any of them in the menu bar, in °C or °F." },
  { title: "Plugged in or on battery", text: "Give each its own mode, like Curve at your desk and Auto on the go. It switches as you plug in or unplug." },
  { title: "Thermal pressure", text: "A coloured dot on the icon when macOS starts slowing your Mac down to cool it." },
  { title: "Hands back cleanly", text: "Fans return to macOS when the app quits, crashes or your Mac sleeps. If macOS isn't ready, they run at full speed until it is." },
  { title: "Barely there", text: "It reads only what's on screen: well under 1% CPU, and its helper sleeps when there's nothing to do." },
  { title: "Keeps itself current", text: "Signed updates install in the background, without stealing focus." },
];

export function Details() {
  return (
    <section className="mx-auto max-w-5xl px-6 pt-32">
      <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">The details.</h2>
      <dl className="mt-12 grid gap-x-12 sm:grid-cols-2">
        {details.map(({ title, text }) => (
          <div key={title} className="border-t border-white/10 py-6">
            <dt className="font-medium text-white">{title}</dt>
            <dd className="mt-2 leading-relaxed text-neutral-400">{text}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
