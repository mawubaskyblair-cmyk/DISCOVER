/*
 * 04_poultry_profit.cpp  (C++)
 * Poultry (layers/broilers) farm profit planner.
 * Estimates feed cost, mortality, revenue, profit and break-even price.
 * Compile: g++ -std=c++17 04_poultry_profit.cpp -o poultry
 */
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <limits>
#include <locale>

using namespace std;

struct FarmInput {
    string type;           // "broiler" or "layer"
    int chicks;            // number of chicks bought
    double chickPrice;     // UGX per chick
    double feedPerBirdKg;  // total kg of feed per bird over the cycle
    double feedPricePerKg; // UGX per kg
    double medicineCost;   // total vaccines + drugs
    double laborCost;      // total labour
    double otherCost;      // water, charcoal, transport, housing
    double mortalityPct;   // % of birds that die
    double sellingPrice;   // UGX per bird (broiler) or per tray of 30 eggs (layer)
    int cycleWeeks;        // broiler ~ 8, layer laying period ~ 52
    double eggsPerBirdPerWeek; // layers only
};

struct Result {
    double chickCost, feedCost, totalCost;
    int survivors;
    double revenue, profit, roiPct, breakEvenPrice, profitPerMonth;
};

string money(double v) {
    long long n = static_cast<long long>(v + (v >= 0 ? 0.5 : -0.5));
    string s = to_string(llabs(n));
    for (int i = static_cast<int>(s.size()) - 3; i > 0; i -= 3) s.insert(i, ",");
    return string("UGX ") + (n < 0 ? "-" : "") + s;
}

template <typename T>
T readValue(const string& prompt, T minimum) {
    T value;
    while (true) {
        cout << prompt;
        if (cin >> value && value >= minimum) return value;
        cout << "  Invalid input, try again.\n";
        cin.clear();
        cin.ignore(numeric_limits<streamsize>::max(), '\n');
    }
}

Result calculate(const FarmInput& f) {
    Result r{};
    r.chickCost = f.chicks * f.chickPrice;
    r.feedCost = f.chicks * f.feedPerBirdKg * f.feedPricePerKg;
    r.totalCost = r.chickCost + r.feedCost + f.medicineCost + f.laborCost + f.otherCost;
    r.survivors = static_cast<int>(f.chicks * (1.0 - f.mortalityPct / 100.0));

    if (f.type == "broiler") {
        r.revenue = r.survivors * f.sellingPrice;
        r.breakEvenPrice = r.survivors > 0 ? r.totalCost / r.survivors : 0;
    } else {
        double totalEggs = r.survivors * f.eggsPerBirdPerWeek * f.cycleWeeks;
        double trays = totalEggs / 30.0;
        r.revenue = trays * f.sellingPrice;
        r.breakEvenPrice = trays > 0 ? r.totalCost / trays : 0;
    }
    r.profit = r.revenue - r.totalCost;
    r.roiPct = r.totalCost > 0 ? (r.profit / r.totalCost) * 100.0 : 0;
    double months = f.cycleWeeks / 4.345;
    r.profitPerMonth = months > 0 ? r.profit / months : 0;
    return r;
}

void printReport(const FarmInput& f, const Result& r) {
    cout << "\n=========== FARM REPORT (" << f.type << ") ===========\n";
    cout << left << setw(26) << "Chicks bought"       << f.chicks << "\n";
    cout << left << setw(26) << "Birds surviving"     << r.survivors << "\n";
    cout << left << setw(26) << "Chick cost"          << money(r.chickCost) << "\n";
    cout << left << setw(26) << "Feed cost"           << money(r.feedCost) << "\n";
    cout << left << setw(26) << "Medicine"            << money(f.medicineCost) << "\n";
    cout << left << setw(26) << "Labour"              << money(f.laborCost) << "\n";
    cout << left << setw(26) << "Other costs"         << money(f.otherCost) << "\n";
    cout << string(44, '-') << "\n";
    cout << left << setw(26) << "TOTAL COST"          << money(r.totalCost) << "\n";
    cout << left << setw(26) << "EXPECTED REVENUE"    << money(r.revenue) << "\n";
    cout << left << setw(26) << "PROFIT / LOSS"       << money(r.profit) << "\n";
    cout << left << setw(26) << "Return on investment" << fixed << setprecision(1) << r.roiPct << "%\n";
    cout << left << setw(26) << "Profit per month"    << money(r.profitPerMonth) << "\n";
    cout << left << setw(26) << "Break-even price"    << money(r.breakEvenPrice)
         << (f.type == "broiler" ? " per bird" : " per tray") << "\n";
    if (r.profit < 0) cout << "\n! You are making a LOSS. Reduce feed waste or raise the price.\n";
    else if (r.roiPct < 15) cout << "\n! Margin is thin. Look for cheaper feed or better market.\n";
    else cout << "\nGood plan. Keep records and vaccinate on time.\n";
}

int main() {
    FarmInput f;
    cout << "=== POULTRY PROFIT PLANNER ===\n";
    cout << "Type (broiler/layer): ";
    cin >> f.type;
    if (f.type != "layer") f.type = "broiler";

    f.chicks         = readValue<int>("Number of chicks: ", 1);
    f.chickPrice     = readValue<double>("Price per chick (UGX): ", 0);
    f.feedPerBirdKg  = readValue<double>("Feed per bird for whole cycle (kg): ", 0);
    f.feedPricePerKg = readValue<double>("Feed price per kg (UGX): ", 0);
    f.medicineCost   = readValue<double>("Medicine/vaccines total (UGX): ", 0);
    f.laborCost      = readValue<double>("Labour total (UGX): ", 0);
    f.otherCost      = readValue<double>("Other costs total (UGX): ", 0);
    f.mortalityPct   = readValue<double>("Expected mortality (%): ", 0);
    f.cycleWeeks     = readValue<int>("Cycle length (weeks): ", 1);
    f.eggsPerBirdPerWeek = 0;
    if (f.type == "layer") {
        f.eggsPerBirdPerWeek = readValue<double>("Eggs per bird per week (about 5-6): ", 0);
        f.sellingPrice = readValue<double>("Selling price per tray of 30 (UGX): ", 0);
    } else {
        f.sellingPrice = readValue<double>("Selling price per bird (UGX): ", 0);
    }

    Result r = calculate(f);
    printReport(f, r);
    return 0;
}