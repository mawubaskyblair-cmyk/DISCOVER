<?php
/**
 * 05_invoice_generator.php  (PHP)
 * Invoice & receipt generator for freelancers, tailors, welders, printers,
 * photographers and any small service business. Run from the command line:
 *     php 05_invoice_generator.php
 * Saves each invoice as an HTML file you can print or send on WhatsApp/PDF.
 */

const BUSINESS_NAME  = "My Business Ltd";
const BUSINESS_PHONE = "+256 7XX XXX XXX";
const BUSINESS_PLACE = "Mukono, Uganda";
const VAT_RATE       = 0.18; // Uganda VAT 18% (set to 0 if not VAT registered)

function ugx(float $amount): string {
    return "UGX " . number_format($amount, 0, ".", ",");
}

function ask(string $prompt): string {
    echo $prompt;
    return trim((string) fgets(STDIN));
}

function nextInvoiceNumber(): string {
    $file = __DIR__ . "/invoice_counter.txt";
    $n = file_exists($file) ? (int) file_get_contents($file) : 0;
    $n++;
    file_put_contents($file, (string) $n);
    return "INV-" . date("Y") . "-" . str_pad((string) $n, 4, "0", STR_PAD_LEFT);
}

function collectItems(): array {
    $items = [];
    echo "\nAdd items. Leave description empty to finish.\n";
    while (true) {
        $desc = ask("Description: ");
        if ($desc === "") {
            break;
        }
        $qty = (float) ask("Quantity: ");
        $price = (float) ask("Unit price (UGX): ");
        if ($qty <= 0 || $price < 0) {
            echo "Invalid quantity or price, item skipped.\n";
            continue;
        }
        $items[] = ["desc" => $desc, "qty" => $qty, "price" => $price, "total" => $qty * $price];
    }
    return $items;
}

function totals(array $items, bool $withVat, float $discount): array {
    $subtotal = array_sum(array_column($items, "total"));
    $afterDiscount = max(0, $subtotal - $discount);
    $vat = $withVat ? $afterDiscount * VAT_RATE : 0;
    return [
        "subtotal" => $subtotal,
        "discount" => $discount,
        "vat"      => $vat,
        "grand"    => $afterDiscount + $vat,
    ];
}

function renderHtml(string $number, string $client, string $phone, array $items, array $t, float $paid): string {
    $rows = "";
    foreach ($items as $i => $it) {
        $rows .= sprintf(
            "<tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
            $i + 1,
            htmlspecialchars($it["desc"]),
            $it["qty"],
            ugx($it["price"]),
            ugx($it["total"])
        );
    }
    $balance = $t["grand"] - $paid;
    $status = $balance <= 0 ? "PAID" : "BALANCE DUE";
    $date = date("d M Y");
    $clientSafe = htmlspecialchars($client);
    $phoneSafe = htmlspecialchars($phone);

    return <<<HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{$number}</title>
<style>
 body{font-family:Arial,sans-serif;max-width:720px;margin:30px auto;color:#222}
 h1{margin:0} table{width:100%;border-collapse:collapse;margin-top:20px}
 th,td{border:1px solid #ccc;padding:8px;text-align:left}
 th{background:#f0f0f0} .right{text-align:right}
 .status{font-size:22px;font-weight:bold;margin-top:20px}
</style></head><body>
<h1>{$number}</h1>
<p><strong>%BIZ%</strong><br>%PHONE% | %PLACE%</p>
<p>Date: {$date}<br>Bill to: <strong>{$clientSafe}</strong> ({$phoneSafe})</p>
<table>
<tr><th>#</th><th>Description</th><th>Qty</th><th>Unit price</th><th>Total</th></tr>
{$rows}</table>
<table class="right">
<tr><td>Subtotal</td><td>%SUB%</td></tr>
<tr><td>Discount</td><td>%DISC%</td></tr>
<tr><td>VAT</td><td>%VAT%</td></tr>
<tr><td><strong>Grand total</strong></td><td><strong>%GRAND%</strong></td></tr>
<tr><td>Amount paid</td><td>%PAID%</td></tr>
<tr><td>Balance</td><td>%BAL%</td></tr>
</table>
<p class="status">{$status}</p>
<p>Thank you for your business.</p>
</body></html>
HTML;
}

function fillPlaceholders(string $html, array $t, float $paid): string {
    $map = [
        "%BIZ%"   => BUSINESS_NAME,
        "%PHONE%" => BUSINESS_PHONE,
        "%PLACE%" => BUSINESS_PLACE,
        "%SUB%"   => ugx($t["subtotal"]),
        "%DISC%"  => ugx($t["discount"]),
        "%VAT%"   => ugx($t["vat"]),
        "%GRAND%" => ugx($t["grand"]),
        "%PAID%"  => ugx($paid),
        "%BAL%"   => ugx(max(0, $t["grand"] - $paid)),
    ];
    return strtr($html, $map);
}

echo "=== INVOICE GENERATOR ===\n";
$client = ask("Client name: ");
$phone  = ask("Client phone: ");
$items  = collectItems();

if (count($items) === 0) {
    exit("No items entered. Nothing to invoice.\n");
}

$withVat  = strtolower(ask("Add 18% VAT? (y/n): ")) === "y";
$discount = (float) ask("Discount (UGX, 0 for none): ");
$totals   = totals($items, $withVat, $discount);
echo "Grand total: " . ugx($totals["grand"]) . "\n";
$paid     = (float) ask("Amount paid so far: ");

$number = nextInvoiceNumber();
$html   = fillPlaceholders(renderHtml($number, $client, $phone, $items, $totals, $paid), $totals, $paid);
$file   = __DIR__ . "/{$number}.html";
file_put_contents($file, $html);

echo "\nInvoice saved: {$file}\n";
echo "Open it in a browser and print or save as PDF.\n";