import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:expense_tracker/models/expense.dart';
// Import this to load the font from your app's assets.
import 'package:flutter/services.dart' show rootBundle;


/// Generates a PDF expense report from a list of expenses.
///
/// This function now correctly embeds a font to support a wide range of
/// characters, including currency symbols like '₹'.
Future<Uint8List> generateExpensePdf(List<Expense> expenses, String dateRange, String currencySymbol) async {
  final pdf = pw.Document();
  final formatter = DateFormat('MM/dd/yyyy');

  // --- FONT LOADING ---
  // Load the font that supports the currency symbol. Noto Sans is a great choice.
  // The ttf file needs to be added to your assets in pubspec.yaml
  final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final ttf = pw.Font.ttf(fontData);
  final boldTtf = pw.Font.ttf(boldFontData);

  // Define text styles using the loaded font.
  final baseStyle = pw.TextStyle(font: ttf, fontSize: 10);
  final boldStyle = pw.TextStyle(font: boldTtf, fontSize: 10);
  final headerStyle = pw.TextStyle(font: boldTtf, fontSize: 18);
  final totalStyle = pw.TextStyle(font: boldTtf, fontSize: 14, color: PdfColors.green);

  // --- DATA PREPARATION ---
  final headers = ['Date', 'Title', 'Category', 'Amount'];
  final data = expenses.map((expense) {
    return [
      formatter.format(expense.date),
      expense.title,
      expense.category.toUpperCase(),
      '$currencySymbol${expense.amount.toStringAsFixed(2)}',
    ];
  }).toList();
  
  final totalAmount = expenses.fold(0.0, (sum, item) => sum + item.amount);

  // --- PDF LAYOUT ---
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf), // Apply theme
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Expense Report', style: headerStyle),
                pw.Text(dateRange, style: baseStyle.copyWith(color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: boldStyle.copyWith(color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(),
          ),
          pw.Divider(),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total:', style: boldStyle.copyWith(fontSize: 14)),
                pw.SizedBox(width: 10),
                pw.Text('$currencySymbol${totalAmount.toStringAsFixed(2)}', style: totalStyle),
              ]
            )
          ),
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text(
              'Report generated on: ${DateFormat.yMMMd().add_jms().format(DateTime.now())}',
              style: baseStyle.copyWith(color: PdfColors.grey, font: ttf),
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}
