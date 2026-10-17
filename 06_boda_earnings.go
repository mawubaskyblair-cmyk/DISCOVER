// 06_boda_earnings.go  (Go)
// Daily earnings tracker for boda boda / taxi / delivery riders.
// Records trips, fuel, repairs and the owner's daily remittance, then shows
// real profit and how long until the motorcycle is paid off.
// Run: go run 06_boda_earnings.go
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

const dataFile = "boda_data.json"

type Entry struct {
	Date     string  `json:"date"`
	Income   float64 `json:"income"`
	Fuel     float64 `json:"fuel"`
	Repairs  float64 `json:"repairs"`
	Remit    float64 `json:"remit"` // paid to bike owner / loan installment
	Trips    int     `json:"trips"`
	Personal float64 `json:"personal"`
}

type Store struct {
	BikePrice float64 `json:"bike_price"`
	Entries   []Entry `json:"entries"`
}

var reader = bufio.NewReader(os.Stdin)

func prompt(msg string) string {
	fmt.Print(msg)
	text, _ := reader.ReadString('\n')
	return strings.TrimSpace(text)
}

func promptFloat(msg string) float64 {
	for {
		v, err := strconv.ParseFloat(prompt(msg), 64)
		if err == nil && v >= 0 {
			return v
		}
		fmt.Println("  Enter a valid number.")
	}
}

func load() Store {
	var s Store
	data, err := os.ReadFile(dataFile)
	if err == nil {
		_ = json.Unmarshal(data, &s)
	}
	return s
}

func (s Store) save() {
	data, _ := json.MarshalIndent(s, "", "  ")
	_ = os.WriteFile(dataFile, data, 0644)
}

func ugx(v float64) string {
	neg := v < 0
	n := int64(v + 0.5)
	if neg {
		n = int64(v - 0.5)
		n = -n
	}
	s := strconv.FormatInt(n, 10)
	for i := len(s) - 3; i > 0; i -= 3 {
		s = s[:i] + "," + s[i:]
	}
	if neg {
		s = "-" + s
	}
	return "UGX " + s
}

func (e Entry) profit() float64 { return e.Income - e.Fuel - e.Repairs - e.Remit }
func (e Entry) takeHome() float64 { return e.profit() - e.Personal }

func (s *Store) addDay() {
	date := prompt("Date (YYYY-MM-DD, blank = today): ")
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	e := Entry{Date: date}
	e.Income = promptFloat("Total money earned: ")
	e.Trips = int(promptFloat("Number of trips: "))
	e.Fuel = promptFloat("Fuel cost: ")
	e.Repairs = promptFloat("Repairs / spare parts: ")
	e.Remit = promptFloat("Remittance to owner or loan installment: ")
	e.Personal = promptFloat("Personal spending today (food, airtime): ")
	s.Entries = append(s.Entries, e)
	s.save()
	fmt.Printf("Saved. Profit today: %s | Saved after spending: %s\n", ugx(e.profit()), ugx(e.takeHome()))
}

func (s Store) monthReport() {
	month := time.Now().Format("2006-01")
	var income, fuel, repairs, remit, saved float64
	days, trips := 0, 0
	for _, e := range s.Entries {
		if strings.HasPrefix(e.Date, month) {
			income += e.Income
			fuel += e.Fuel
			repairs += e.Repairs
			remit += e.Remit
			saved += e.takeHome()
			trips += e.Trips
			days++
		}
	}
	if days == 0 {
		fmt.Println("No records this month.")
		return
	}
	fmt.Printf("\n--- %s REPORT (%d working days) ---\n", month, days)
	fmt.Println("Income      :", ugx(income))
	fmt.Println("Fuel        :", ugx(fuel))
	fmt.Println("Repairs     :", ugx(repairs))
	fmt.Println("Remittance  :", ugx(remit))
	fmt.Println("Net savings :", ugx(saved))
	fmt.Printf("Average per day: %s over %d trips (%s per trip)\n",
		ugx(income/float64(days)), trips, ugx(income/float64(max(trips, 1))))
	if income > 0 {
		fmt.Printf("Fuel is %.0f%% of income.\n", fuel/income*100)
	}
}

func (s Store) bestDays() {
	list := append([]Entry{}, s.Entries...)
	sort.Slice(list, func(i, j int) bool { return list[i].profit() > list[j].profit() })
	fmt.Println("\nTop 5 most profitable days:")
	for i := 0; i < len(list) && i < 5; i++ {
		fmt.Printf(" %d. %s  profit %s\n", i+1, list[i].Date, ugx(list[i].profit()))
	}
}

func (s *Store) payoff() {
	if s.BikePrice == 0 {
		s.BikePrice = promptFloat("Price of your motorcycle: ")
		s.save()
	}
	var saved float64
	for _, e := range s.Entries {
		saved += e.takeHome()
	}
	left := s.BikePrice - saved
	fmt.Println("Total saved so far:", ugx(saved))
	if left <= 0 {
		fmt.Println("Congratulations! You can now own the bike outright.")
		return
	}
	avg := saved / float64(max(len(s.Entries), 1))
	if avg <= 0 {
		fmt.Println("Savings are not growing yet. Cut costs or work more trips.")
		return
	}
	fmt.Printf("Still need %s, about %.0f more working days.\n", ugx(left), left/avg)
}

func main() {
	s := load()
	for {
		fmt.Println("\n=== BODA EARNINGS ===\n1 Add day\n2 Month report\n3 Best days\n4 Bike payoff estimate\n0 Exit")
		switch prompt("Choose: ") {
		case "1":
			s.addDay()
		case "2":
			s.monthReport()
		case "3":
			s.bestDays()
		case "4":
			s.payoff()
		case "0":
			return
		default:
			fmt.Println("Invalid choice.")
		}
	}
}