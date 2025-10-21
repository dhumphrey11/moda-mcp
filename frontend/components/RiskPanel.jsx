export default function RiskPanel({ cash = 10000, maxPosition = 1000 }) {
  return (
    <div className="border rounded p-4 shadow-sm bg-white">
      <h3 className="font-semibold">Risk</h3>
      <div className="text-sm text-gray-600">Cash: ${cash.toLocaleString()}</div>
      <div className="text-sm">Max Position: ${maxPosition.toLocaleString()}</div>
    </div>
  );
}
