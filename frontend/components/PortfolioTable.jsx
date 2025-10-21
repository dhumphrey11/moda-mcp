export default function PortfolioTable({ rows = [] }) {
  const data = rows.length ? rows : [
    { symbol: 'BTC', qty: 0.25, price: 65000, value: 16250 },
    { symbol: 'ETH', qty: 1.2, price: 3500, value: 4200 },
  ];
  return (
    <table className="min-w-full text-left text-sm">
      <thead>
        <tr className="border-b">
          <th className="p-2">Symbol</th>
          <th className="p-2">Qty</th>
          <th className="p-2">Price</th>
          <th className="p-2">Value</th>
        </tr>
      </thead>
      <tbody>
        {data.map((r, i) => (
          <tr key={i} className="border-b">
            <td className="p-2">{r.symbol}</td>
            <td className="p-2">{r.qty}</td>
            <td className="p-2">${r.price.toLocaleString()}</td>
            <td className="p-2">${r.value.toLocaleString()}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
