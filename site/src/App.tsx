import { Features } from "./components/Features.tsx";
import { Footer } from "./components/Footer.tsx";
import { Hero } from "./components/Hero.tsx";
import { Install } from "./components/Install.tsx";
import { Modes } from "./components/Modes.tsx";
import { Nav } from "./components/Nav.tsx";
import { SettingsSection } from "./components/SettingsSection.tsx";

export function App() {
  return (
    <div className="relative overflow-x-clip">
      <Backdrop />
      <Nav />
      <main className="relative">
        <Hero />
        <Features />
        <Modes />
        <SettingsSection />
        <Install />
      </main>
      <Footer />
    </div>
  );
}

/** Soft coloured light behind the top of the page. */
function Backdrop() {
  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 top-0 h-[900px]">
      <div className="absolute -top-40 left-1/2 h-[600px] w-[900px] -translate-x-1/2 rounded-full bg-accent/20 blur-[140px]" />
      <div className="absolute top-60 -right-40 h-[400px] w-[500px] rounded-full bg-sky-500/10 blur-[120px]" />
    </div>
  );
}
