import { CurveDemo } from "./components/CurveDemo.tsx";
import { Details } from "./components/Details.tsx";
import { Download } from "./components/Download.tsx";
import { Footer } from "./components/Footer.tsx";
import { Header } from "./components/Header.tsx";
import { Hero } from "./components/Hero.tsx";
import { Modes } from "./components/Modes.tsx";

export function App() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Modes />
        <CurveDemo />
        <Details />
        <Download />
      </main>
      <Footer />
    </>
  );
}
