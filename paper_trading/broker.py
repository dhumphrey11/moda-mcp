"""Simple broker simulator placeholder."""

class Broker:
    def __init__(self, starting_cash: float = 10000.0):
        self.cash = starting_cash
        self.positions = {}

    def buy(self, symbol: str, qty: float, price: float):
        cost = qty * price
        if cost > self.cash:
            return False
        self.cash -= cost
        self.positions[symbol] = self.positions.get(symbol, 0.0) + qty
        return True

    def sell(self, symbol: str, qty: float, price: float):
        pos = self.positions.get(symbol, 0.0)
        if qty > pos:
            return False
        self.positions[symbol] = pos - qty
        self.cash += qty * price
        return True
