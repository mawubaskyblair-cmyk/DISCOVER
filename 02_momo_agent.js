/**
 * 02_momo_agent.js  (JavaScript / Node.js)
 * Mobile-money agent ledger: records deposits and withdrawals,
 * calculates commission, tracks float and daily earnings.
 * Run:  node 02_momo_agent.js
 */
const readline = require("readline");
const fs = require("fs");

const FILE = "momo_ledger.json";

// Commission tiers (UGX). Edit these to match your network's real rates.
const COMMISSION_TIERS = [
  { max: 5000, rate: 50 },
  { max: 30000, rate: 200 },
  { max: 100000, rate: 500 },
  { max: 500000, rate: 1200 },
  { max: Infinity, rate: 2500 },
];

let state = { float: 0, cash: 0, transactions: [] };

function load() {
  if (fs.existsSync(FILE)) {
    state = JSON.parse(fs.readFileSync(FILE, "utf8"));
  }
}

function save() {
  fs.writeFileSync(FILE, JSON.stringify(state, null, 2));
}

function fmt(n) {
  return "UGX " + Math.round(n).toLocaleString("en-US");
}

function commissionFor(amount) {
  const tier = COMMISSION_TIERS.find((t) => amount <= t.max);
  return tier.rate;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function setOpening(floatAmt, cashAmt) {
  state.float = floatAmt;
  state.cash = cashAmt;
  save();
  console.log(`Opening balances set. Float ${fmt(floatAmt)}, Cash ${fmt(cashAmt)}`);
}

// Customer deposits cash -> agent cash goes UP, e-float goes DOWN.
function deposit(amount, phone) {
  if (amount > state.float) {
    console.log("Not enough e-float! Top up first.");
    return;
  }
  const commission = commissionFor(amount);
  state.float -= amount;
  state.cash += amount;
  state.transactions.push({ type: "DEPOSIT", amount, phone, commission, date: today() });
  save();
  console.log(`Deposit OK. Commission earned: ${fmt(commission)}`);
}

// Customer withdraws cash -> agent cash goes DOWN, e-float goes UP.
function withdraw(amount, phone) {
  if (amount > state.cash) {
    console.log("Not enough cash in drawer!");
    return;
  }
  const commission = commissionFor(amount);
  state.float += amount;
  state.cash -= amount;
  state.transactions.push({ type: "WITHDRAW", amount, phone, commission, date: today() });
  save();
  console.log(`Withdrawal OK. Commission earned: ${fmt(commission)}`);
}

function balances() {
  console.log("\n--- BALANCES ---");
  console.log("E-float :", fmt(state.float));
  console.log("Cash    :", fmt(state.cash));
  console.log("Total   :", fmt(state.float + state.cash));
  if (state.float < 200000) console.log("! Float is low, consider topping up.");
  if (state.cash < 200000) console.log("! Cash is low, consider banking/withdrawing.");
}

function report(day = today()) {
  const list = state.transactions.filter((t) => t.date === day);
  if (list.length === 0) {
    console.log("No transactions on", day);
    return;
  }
  const deposits = list.filter((t) => t.type === "DEPOSIT");
  const withdrawals = list.filter((t) => t.type === "WITHDRAW");
  const sum = (arr, key) => arr.reduce((s, t) => s + t[key], 0);
  console.log(`\n--- REPORT ${day} ---`);
  console.log(`Deposits   : ${deposits.length} totalling ${fmt(sum(deposits, "amount"))}`);
  console.log(`Withdrawals: ${withdrawals.length} totalling ${fmt(sum(withdrawals, "amount"))}`);
  console.log(`Commission : ${fmt(sum(list, "commission"))}`);
}

function monthlyEarnings() {
  const month = today().slice(0, 7);
  const total = state.transactions
    .filter((t) => t.date.startsWith(month))
    .reduce((s, t) => s + t.commission, 0);
  console.log(`Commission earned this month (${month}): ${fmt(total)}`);
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise((res) => rl.question(q, res));

async function main() {
  load();
  while (true) {
    console.log("\n=== MOMO AGENT ===\n1 Set opening balances\n2 Deposit\n3 Withdraw\n" +
      "4 Balances\n5 Daily report\n6 Monthly commission\n0 Exit");
    const c = (await ask("Choose: ")).trim();
    if (c === "0") break;
    if (c === "1") setOpening(Number(await ask("E-float: ")), Number(await ask("Cash: ")));
    else if (c === "2") deposit(Number(await ask("Amount: ")), await ask("Phone: "));
    else if (c === "3") withdraw(Number(await ask("Amount: ")), await ask("Phone: "));
    else if (c === "4") balances();
    else if (c === "5") report();
    else if (c === "6") monthlyEarnings();
    else console.log("Invalid choice.");
  }
  rl.close();
}

main();