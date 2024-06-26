import { Button } from "@/components/ui/button";
import { Confetti } from "@/components/ui/confetti";

export function ConfettiSideCannons() {
  const handleClick = () => {
    const end = Date.now() + 2 * 1000;
    const colors = ["#a786ff", "#fd8bbc", "#eca184", "#f8deb1"];

    const frame = () => {
      if (Date.now() > end) return;

      Confetti({
        particleCount: 2,
        angle: 60,
        spread: 55,
        startVelocity: 60,
        origin: { x: 0, y: 0.5 },
        colors: colors,
      });
      Confetti({
        particleCount: 2,
        angle: 120,
        spread: 55,
        startVelocity: 60,
        origin: { x: 1, y: 0.5 },
        colors: colors,
      });

      requestAnimationFrame(frame);
    };

    frame();
  };

  return (
    <div className="relative justify-center">
      <Button onClick={handleClick}>Trigger Side Cannons</Button>
    </div>
  );
}
