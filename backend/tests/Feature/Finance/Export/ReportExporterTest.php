<?php

namespace Tests\Feature\Finance\Export;

use App\Domain\Finance\Reports\Export\ReportExporter;
use Tests\TestCase;

class ReportExporterTest extends TestCase
{
    private function build(): ReportExporter
    {
        return (new ReportExporter)
            ->sheetTitle('Por categoría')
            ->header('Por categoría', 'Rango: 2026-05-01 a 2026-05-31');
    }

    public function test_writes_header_in_first_two_rows(): void
    {
        $exp = $this->build();
        $bin = $exp->toBinary();
        $sheet = ReportExporter::loadFromBinary($bin)->getActiveSheet();

        $this->assertSame('Por categoría', $sheet->getTitle());
        $this->assertSame('Por categoría', $sheet->getCell('A1')->getValue());
        $this->assertTrue($sheet->getStyle('A1')->getFont()->getBold());
        $this->assertSame(14.0, (float) $sheet->getStyle('A1')->getFont()->getSize());

        $subtitle = (string) $sheet->getCell('A2')->getValue();
        $this->assertStringContainsString('Rango: 2026-05-01 a 2026-05-31', $subtitle);
        $this->assertStringContainsString('Generado el', $subtitle);
        $this->assertTrue($sheet->getStyle('A2')->getFont()->getItalic());
    }

    public function test_table_writes_headers_bold_with_fill_and_data_rows(): void
    {
        $exp = $this->build()->table(
            ['Categoría', 'Movimientos', 'Total'],
            [
                ['Comida', 12, 1500.50],
                ['Transporte', 4, 200.00],
            ],
            [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_INT, ReportExporter::FORMAT_MONEY]
        );

        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();

        // Headers en fila 4.
        $this->assertSame('Categoría', $sheet->getCell('A4')->getValue());
        $this->assertSame('Movimientos', $sheet->getCell('B4')->getValue());
        $this->assertSame('Total', $sheet->getCell('C4')->getValue());
        $this->assertTrue($sheet->getStyle('A4')->getFont()->getBold());

        // Data en filas 5-6.
        $this->assertSame('Comida', $sheet->getCell('A5')->getValue());
        $this->assertEquals(12, $sheet->getCell('B5')->getValue());
        $this->assertEquals(1500.50, $sheet->getCell('C5')->getValue());
        $this->assertSame('Transporte', $sheet->getCell('A6')->getValue());
        $this->assertEquals(200.00, $sheet->getCell('C6')->getValue());
    }

    public function test_applies_money_format_to_money_columns(): void
    {
        $exp = $this->build()->table(
            ['Categoría', 'Total'],
            [['Comida', 1500.50]],
            [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_MONEY]
        );

        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();
        $this->assertSame(
            ReportExporter::MONEY_FORMAT_CODE,
            $sheet->getStyle('B5')->getNumberFormat()->getFormatCode()
        );
    }

    public function test_applies_percentage_format_to_pct_columns(): void
    {
        $exp = $this->build()->table(
            ['Categoría', '% consumido'],
            [['Comida', 0.65]],
            [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_PCT]
        );

        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();
        $this->assertSame(
            ReportExporter::PCT_FORMAT_CODE,
            $sheet->getStyle('B5')->getNumberFormat()->getFormatCode()
        );
    }

    public function test_empty_table_only_renders_headers_and_footer_zero(): void
    {
        $exp = $this->build()
            ->table(['Categoría', 'Total'], [], [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_MONEY])
            ->footer(['TOTAL', 0]);

        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();
        // Header en fila 4; sin data rows; footer en fila 5.
        $this->assertSame('Categoría', $sheet->getCell('A4')->getValue());
        $this->assertSame('TOTAL', $sheet->getCell('A5')->getValue());
        $this->assertEquals(0, $sheet->getCell('B5')->getValue());
        $this->assertTrue($sheet->getStyle('A5')->getFont()->getBold());
        $this->assertSame(
            ReportExporter::MONEY_FORMAT_CODE,
            $sheet->getStyle('B5')->getNumberFormat()->getFormatCode()
        );
    }

    public function test_footer_with_empty_array_does_not_write_row(): void
    {
        $exp = $this->build()
            ->table(['Tarjeta'], [['Visa'], ['Mastercard']], [ReportExporter::FORMAT_TEXT])
            ->footer([]);

        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();
        // No debe haber fila 7 (las tarjetas terminan en fila 6: header=4, Visa=5, MC=6).
        $this->assertNull($sheet->getCell('A7')->getValue());
        // Y la fila 6 no debe estar bold (la última fila de tarjetas es data normal).
        $this->assertFalse($sheet->getStyle('A6')->getFont()->getBold());
    }

    public function test_truncates_long_sheet_title_to_31_chars(): void
    {
        $longTitle = 'Reporte super largo que excede los 31 caracteres permitidos';
        $exp = (new ReportExporter)->sheetTitle($longTitle);
        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();

        $this->assertLessThanOrEqual(31, mb_strlen($sheet->getTitle()));
        $this->assertSame(mb_substr($longTitle, 0, 31), $sheet->getTitle());
    }

    public function test_sheet_title_replaces_invalid_chars(): void
    {
        $exp = (new ReportExporter)->sheetTitle('A/B*C[D]');
        $sheet = ReportExporter::loadFromBinary($exp->toBinary())->getActiveSheet();

        $this->assertSame('A-B-C-D-', $sheet->getTitle());
    }

    public function test_download_returns_streamed_response_with_correct_headers(): void
    {
        $response = $this->build()
            ->table(['Categoría', 'Total'], [['X', 10]], [ReportExporter::FORMAT_TEXT, ReportExporter::FORMAT_MONEY])
            ->footer(['TOTAL', 10])
            ->download('fincore-por-categoria-2026-05-01_2026-05-31.xlsx');

        $this->assertSame(200, $response->getStatusCode());
        $this->assertStringContainsString(
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            (string) $response->headers->get('Content-Type')
        );
        $this->assertStringContainsString('attachment', (string) $response->headers->get('Content-Disposition'));
        $this->assertStringContainsString(
            'fincore-por-categoria-2026-05-01_2026-05-31.xlsx',
            (string) $response->headers->get('Content-Disposition')
        );
    }

    public function test_to_binary_starts_with_zip_magic_bytes(): void
    {
        $bin = $this->build()
            ->table(['X'], [['v']], [ReportExporter::FORMAT_TEXT])
            ->toBinary();

        $this->assertSame("PK\x03\x04", substr($bin, 0, 4));
    }

    public function test_throws_when_headers_and_formats_lengths_differ(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        (new ReportExporter)
            ->sheetTitle('X')
            ->header('X', 'Y')
            ->table(['A', 'B'], [], [ReportExporter::FORMAT_TEXT]); // 2 vs 1
    }
}
