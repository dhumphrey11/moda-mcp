export default function SignalCard({ title = "BTC Breakout", score = 0.0, label = "hold" }) {
  return (
    <div className="border rounded p-4 shadow-sm bg-white">
      <h3 className="font-semibold">{title}</h3>
      <div className="text-sm text-gray-600">Score: {score}</div>
      <div className="text-sm">Action: <span className="font-medium">{label}</span></div>
    </div>
  );
}
