// 07_PayrollCalculator.cs  (C#)
// Payroll calculator for small employers in Uganda: PAYE, NSSF and net pay.
// Helps you run a business legally and pay staff correctly.
// Build/run: dotnet new console -o payroll ; replace Program.cs with this file ; dotnet run
//
// NOTE: Rates below follow the commonly published URA/NSSF schedule. Always
// confirm current rates with URA (ura.go.ug) and NSSF (nssfug.org) before use.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace PayrollApp
{
    class Employee
    {
        public string Name { get; set; } = "";
        public decimal BasicSalary { get; set; }
        public decimal Allowances { get; set; }
        public decimal OtherDeductions { get; set; } // loans, advances, etc.
        public decimal Gross => BasicSalary + Allowances;
    }

    class PayslipLine
    {
        public Employee Emp { get; set; } = new Employee();
        public decimal NssfEmployee { get; set; }
        public decimal NssfEmployer { get; set; }
        public decimal Paye { get; set; }
        public decimal Net { get; set; }
        public decimal TotalCostToEmployer => Emp.Gross + NssfEmployer;
    }

    static class TaxEngine
    {
        const decimal NssfEmployeeRate = 0.05m;
        const decimal NssfEmployerRate = 0.10m;

        public static decimal NssfEmployee(decimal gross) => Math.Round(gross * NssfEmployeeRate);
        public static decimal NssfEmployer(decimal gross) => Math.Round(gross * NssfEmployerRate);

        // Monthly PAYE bands for resident employees.
        public static decimal Paye(decimal gross)
        {
            decimal tax;
            if (gross <= 235_000m)
                tax = 0m;
            else if (gross <= 335_000m)
                tax = (gross - 235_000m) * 0.10m;
            else if (gross <= 410_000m)
                tax = 10_000m + (gross - 335_000m) * 0.20m;
            else
                tax = 25_000m + (gross - 410_000m) * 0.30m;

            // Additional 10% on the portion of gross above UGX 10,000,000.
            if (gross > 10_000_000m)
                tax += (gross - 10_000_000m) * 0.10m;

            return Math.Round(tax);
        }
    }

    class Program
    {
        static readonly List<Employee> Staff = new List<Employee>();

        static string Ugx(decimal v) => "UGX " + v.ToString("N0");

        static decimal ReadDecimal(string prompt)
        {
            while (true)
            {
                Console.Write(prompt);
                if (decimal.TryParse(Console.ReadLine(), out var value) && value >= 0)
                    return value;
                Console.WriteLine("  Please enter a valid amount.");
            }
        }

        static void AddEmployee()
        {
            Console.Write("Employee name: ");
            string name = (Console.ReadLine() ?? "").Trim();
            if (name.Length == 0)
            {
                Console.WriteLine("Name is required.");
                return;
            }
            Staff.Add(new Employee
            {
                Name = name,
                BasicSalary = ReadDecimal("Basic monthly salary: "),
                Allowances = ReadDecimal("Allowances (transport, housing): "),
                OtherDeductions = ReadDecimal("Other deductions (advance/loan): ")
            });
            Console.WriteLine($"{name} added.");
        }

        static PayslipLine Calculate(Employee e)
        {
            decimal nssfEmp = TaxEngine.NssfEmployee(e.Gross);
            decimal nssfEr = TaxEngine.NssfEmployer(e.Gross);
            decimal paye = TaxEngine.Paye(e.Gross);
            decimal net = e.Gross - nssfEmp - paye - e.OtherDeductions;
            return new PayslipLine { Emp = e, NssfEmployee = nssfEmp, NssfEmployer = nssfEr, Paye = paye, Net = net };
        }

        static void ShowPayslip(PayslipLine p)
        {
            Console.WriteLine($"\n---- PAYSLIP: {p.Emp.Name} ----");
            Console.WriteLine($"Basic salary      {Ugx(p.Emp.BasicSalary),18}");
            Console.WriteLine($"Allowances        {Ugx(p.Emp.Allowances),18}");
            Console.WriteLine($"Gross pay         {Ugx(p.Emp.Gross),18}");
            Console.WriteLine($"NSSF (5%)        -{Ugx(p.NssfEmployee),18}");
            Console.WriteLine($"PAYE             -{Ugx(p.Paye),18}");
            Console.WriteLine($"Other deductions -{Ugx(p.Emp.OtherDeductions),18}");
            Console.WriteLine($"NET PAY           {Ugx(p.Net),18}");
            if (p.Net < 0) Console.WriteLine("! Deductions exceed pay. Reduce the advance recovery.");
        }

        static void RunPayroll()
        {
            if (Staff.Count == 0)
            {
                Console.WriteLine("Add employees first.");
                return;
            }
            var lines = Staff.Select(Calculate).ToList();
            foreach (var l in lines) ShowPayslip(l);

            Console.WriteLine("\n======= PAYROLL SUMMARY =======");
            Console.WriteLine($"Employees              : {lines.Count}");
            Console.WriteLine($"Total gross            : {Ugx(lines.Sum(l => l.Emp.Gross))}");
            Console.WriteLine($"Total net to pay       : {Ugx(lines.Sum(l => l.Net))}");
            Console.WriteLine($"PAYE to remit to URA   : {Ugx(lines.Sum(l => l.Paye))}");
            decimal nssfTotal = lines.Sum(l => l.NssfEmployee + l.NssfEmployer);
            Console.WriteLine($"NSSF to remit (15%)    : {Ugx(nssfTotal)}");
            Console.WriteLine($"Total cost to business : {Ugx(lines.Sum(l => l.TotalCostToEmployer))}");
        }

        static void ListStaff()
        {
            if (Staff.Count == 0) { Console.WriteLine("No employees yet."); return; }
            int i = 1;
            foreach (var e in Staff)
                Console.WriteLine($"{i++}. {e.Name,-20} gross {Ugx(e.Gross)}");
        }

        static void Main()
        {
            Console.OutputEncoding = Encoding.UTF8;
            while (true)
            {
                Console.WriteLine("\n=== PAYROLL ===\n1 Add employee\n2 List staff\n3 Run payroll\n0 Exit");
                Console.Write("Choose: ");
                switch (Console.ReadLine())
                {
                    case "1": AddEmployee(); break;
                    case "2": ListStaff(); break;
                    case "3": RunPayroll(); break;
                    case "0": return;
                    default: Console.WriteLine("Invalid choice."); break;
                }
            }
        }
    }
}