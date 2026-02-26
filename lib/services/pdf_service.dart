import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class PdfService {
  // ==========================================
  // 1. STUDENT FUNCTION: Official Letter
  // ==========================================
  Future<void> generateResolutionLetter({
    required String studentName,
    required String complaintId,
    required String issue,
    required String resolutionRemarks,
    required String date,
  }) async {
    final pdf = pw.Document();

    // 🔥 HIGH CLASS FONT INJECTION (Unicode Support)
    // Yeh line Helvetica ke Unicode errors ko fix karti hai
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ), // Global Theme Apply
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, // ✅ Fixed with pw.
            children: [
              // Header Section
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween, // ✅ Fixed with pw.
                  children: [
                    pw.Text(
                      "UNIVERSITY COMPLAINT PORTAL",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      "OFFICIAL RECORD",
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Title Section
              pw.Center(
                child: pw.Text(
                  "COMPLAINT RESOLUTION CERTIFICATE",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // Details Information Box
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start, // ✅ Fixed with pw.
                  children: [
                    _buildRow("Student Name:", studentName),
                    pw.SizedBox(height: 8),
                    _buildRow("Complaint ID:", "#$complaintId"),
                    pw.SizedBox(height: 8),
                    _buildRow("Date Resolved:", date),
                    pw.SizedBox(height: 8),
                    _buildRow("Issue Type:", issue),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Official Remarks Section
              pw.Text(
                "Resolution Remarks:",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(5),
                  ),
                ),
                child: pw.Text(
                  resolutionRemarks,
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.Spacer(),

              // Professional Footer with QR Code
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween, // ✅ Fixed with pw.
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start, // ✅ Fixed with pw.
                    children: [
                      pw.Text(
                        "System Generated Document - No Signature Required",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "This document is a proof of resolution for internal records.",
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                      ),
                      pw.Text(
                        "Verification Link: https://amirdev.site/portal/verify?id=$complaintId",
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data:
                        "COMPLAINT-ID: #$complaintId | STUDENT: $studentName | STATUS: RESOLVED",
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ==========================================
  // 2. RESOLVER FUNCTION: Monthly Report
  // ==========================================
  Future<void> generateResolverReport({
    required String resolverId,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final tableHeaders = [
      'Complaint ID',
      'Category',
      'Current Status',
      'Submission Date',
    ];

    final tableData = tasks.map((task) {
      String rawDate = (task['created_at'] ?? task['timestamp'] ?? '')
          .toString();
      String displayDate = rawDate.length > 10
          ? rawDate.substring(0, 10)
          : rawDate;
      String id = (task['detail_id'] ?? task['id'] ?? 'N/A').toString();
      String status = (task['status'] ?? 'Pending').toString();
      String type =
          (task['complaint_type'] ?? task['complaint_type_detail'] ?? 'General')
              .toString();

      return [id, type, status, displayDate];
    }).toList();

    int total = tasks.length;
    int resolved = tasks
        .where((t) => (t['status'] ?? '').toString() == 'Resolved')
        .length;
    int pending = total - resolved;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              "Report Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween, // ✅ Fixed with pw.
                children: [
                  pw.Text(
                    "ADMINISTRATIVE PERFORMANCE REPORT",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    "Gen: ${DateTime.now().toString().split(' ')[0]}",
                    style: const pw.TextStyle(color: PdfColors.grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween, // ✅ Fixed with pw.
              children: [
                _buildPdfInfoCard("Staff ID", resolverId),
                _buildPdfInfoCard("Total Assigned", "$total"),
                _buildPdfInfoCard(
                  "Resolved",
                  "$resolved",
                  color: PdfColors.green,
                ),
                _buildPdfInfoCard(
                  "Pending",
                  "$pending",
                  color: PdfColors.orange,
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            pw.TableHelper.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              cellPadding: const pw.EdgeInsets.all(10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // HELPER: Professional Row for Letter
  pw.Widget _buildRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  // HELPER: Premium Info Cards for Report
  pw.Widget _buildPdfInfoCard(
    String title,
    String value, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
