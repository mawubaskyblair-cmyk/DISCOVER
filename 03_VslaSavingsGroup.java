/**
 * 03_VslaSavingsGroup.java  (Java)
 * Village Savings & Loan Association (VSLA / SACCO style) manager.
 * Members save weekly, borrow with interest, and the group shares out profit.
 * Compile: javac 03_VslaSavingsGroup.java   Run: java VslaSavingsGroup
 */
import java.util.*;

class VslaSavingsGroup {

    static class Loan {
        double principal;
        double interestRate; // per month, e.g. 0.10 = 10%
        int months;
        double repaid;

        Loan(double principal, double interestRate, int months) {
            this.principal = principal;
            this.interestRate = interestRate;
            this.months = months;
        }

        double totalDue() {
            return principal + principal * interestRate * months;
        }

        double balance() {
            return totalDue() - repaid;
        }
    }

    static class Member {
        final String name;
        double savings = 0;
        List<Loan> loans = new ArrayList<>();

        Member(String name) {
            this.name = name;
        }

        double outstanding() {
            double sum = 0;
            for (Loan l : loans) sum += l.balance();
            return sum;
        }
    }

    private final Map<String, Member> members = new LinkedHashMap<>();
    private double interestEarned = 0;
    private final Scanner in = new Scanner(System.in);

    private String fmt(double v) {
        return String.format("UGX %,.0f", v);
    }

    void addMember() {
        System.out.print("Member name: ");
        String name = in.nextLine().trim();
        if (name.isEmpty() || members.containsKey(name.toLowerCase())) {
            System.out.println("Invalid or duplicate name.");
            return;
        }
        members.put(name.toLowerCase(), new Member(name));
        System.out.println(name + " joined the group.");
    }

    Member find() {
        System.out.print("Member name: ");
        Member m = members.get(in.nextLine().trim().toLowerCase());
        if (m == null) System.out.println("Member not found.");
        return m;
    }

    double readAmount(String prompt) {
        System.out.print(prompt);
        try {
            double v = Double.parseDouble(in.nextLine().trim());
            return v > 0 ? v : -1;
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    void saveMoney() {
        Member m = find();
        if (m == null) return;
        double amt = readAmount("Amount saved: ");
        if (amt < 0) { System.out.println("Invalid amount."); return; }
        m.savings += amt;
        System.out.println(m.name + " savings now " + fmt(m.savings));
    }

    double fundBalance() {
        double saved = 0, lent = 0;
        for (Member m : members.values()) {
            saved += m.savings;
            lent += m.outstanding();
        }
        return saved + interestEarned - lent;
    }

    void giveLoan() {
        Member m = find();
        if (m == null) return;
        double amt = readAmount("Loan amount: ");
        // Rule: a member may borrow up to 3 times their savings.
        if (amt < 0 || amt > m.savings * 3) {
            System.out.println("Loan limit is 3x savings: " + fmt(m.savings * 3));
            return;
        }
        if (amt > fundBalance()) {
            System.out.println("The group fund only has " + fmt(fundBalance()));
            return;
        }
        System.out.print("Months to repay: ");
        int months = Integer.parseInt(in.nextLine().trim());
        Loan loan = new Loan(amt, 0.05, months); // 5% per month
        m.loans.add(loan);
        System.out.println("Loan approved. Total to repay: " + fmt(loan.totalDue()));
    }

    void repay() {
        Member m = find();
        if (m == null) return;
        if (m.outstanding() <= 0) { System.out.println("No active loan."); return; }
        double amt = readAmount("Repayment amount: ");
        if (amt < 0) { System.out.println("Invalid amount."); return; }
        for (Loan l : m.loans) {
            if (l.balance() <= 0) continue;
            double pay = Math.min(amt, l.balance());
            l.repaid += pay;
            amt -= pay;
            // Interest portion goes to the group profit pool.
            double interestShare = l.totalDue() - l.principal;
            interestEarned += pay * (interestShare / l.totalDue());
            if (amt <= 0) break;
        }
        System.out.println("Repayment recorded. Remaining debt: " + fmt(m.outstanding()));
    }

    void summary() {
        System.out.println("\n--- GROUP SUMMARY ---");
        for (Member m : members.values()) {
            System.out.printf("%-15s savings %,12.0f  owes %,12.0f%n", m.name, m.savings, m.outstanding());
        }
        System.out.println("Interest earned : " + fmt(interestEarned));
        System.out.println("Cash in fund    : " + fmt(fundBalance()));
    }

    void shareOut() {
        double totalSavings = 0;
        for (Member m : members.values()) totalSavings += m.savings;
        if (totalSavings == 0) { System.out.println("No savings to share."); return; }
        System.out.println("\n--- END OF CYCLE SHARE-OUT ---");
        for (Member m : members.values()) {
            double profitShare = interestEarned * (m.savings / totalSavings);
            System.out.printf("%-15s gets %,12.0f (savings + %,.0f profit)%n",
                    m.name, m.savings + profitShare, profitShare);
        }
    }

    void run() {
        while (true) {
            System.out.println("\n=== VSLA ===\n1 Add member\n2 Save\n3 Give loan\n4 Repay\n5 Summary\n6 Share-out\n0 Exit");
            System.out.print("Choose: ");
            String c = in.nextLine().trim();
            switch (c) {
                case "1": addMember(); break;
                case "2": saveMoney(); break;
                case "3": giveLoan(); break;
                case "4": repay(); break;
                case "5": summary(); break;
                case "6": shareOut(); break;
                case "0": return;
                default: System.out.println("Invalid choice.");
            }
        }
    }

    public static void main(String[] args) {
        new VslaSavingsGroup().run();
    }
}