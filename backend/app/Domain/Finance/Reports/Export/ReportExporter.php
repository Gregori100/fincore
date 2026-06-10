<?php

namespace App\Domain\Finance\Reports\Export;

use Carbon\CarbonImmutable;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Helper único para construir los xlsx de los 6 reportes de FinCore.
 *
 * Centraliza toda la API de PhpSpreadsheet en métodos finos para no esparcirla
 * por 6 controllers. Es fluent: cada método (salvo download) devuelve $this.
 *
 * Layout estándar:
 *   Fila 1: nombre del reporte (bold, size 14).
 *   Fila 2: rango/contexto + fecha de generación (cursiva, size 10).
 *   Fila 3: vacía.
 *   Fila 4: headers (bold, fondo gris claro).
 *   Filas 5..N: filas de data con formato por columna.
 *   Fila N+1: footer opcional (bold).
 *
 * Formatos por columna:
 *   - 'money' → "$"#,##0.00
 *   - 'pct'   → 0.0%
 *   - 'int'   → 0
 *   - 'text'  → default
 */
final class ReportExporter
{
    public const FORMAT_MONEY = 'money';

    public const FORMAT_PCT = 'pct';

    public const FORMAT_INT = 'int';

    public const FORMAT_TEXT = 'text';

    public const MONEY_FORMAT_CODE = '"$"#,##0.00';

    public const PCT_FORMAT_CODE = '0.0%';

    public const INT_FORMAT_CODE = '0';

    private const HEADER_FILL_COLOR = 'FFEFEFEF';

    private const SHEET_TITLE_MAX_LEN = 31;

    private Spreadsheet $spreadsheet;

    private int $nextRow = 1;

    private int $tableHeaderRow = 0;

    private int $tableLastDataRow = 0;

    /** @var array<int, string> */
    private array $columnFormats = [];

    private int $columnCount = 0;

    public function __construct()
    {
        $this->spreadsheet = new Spreadsheet;
    }

    public function sheetTitle(string $title): self
    {
        $safe = mb_substr($title, 0, self::SHEET_TITLE_MAX_LEN);
        // Excel rechaza estos caracteres en nombres de hoja.
        $safe = preg_replace('/[\\\\\/\\?\\*\\[\\]:]/', '-', $safe) ?? $safe;
        $this->spreadsheet->getActiveSheet()->setTitle($safe);

        return $this;
    }

    /**
     * Escribe filas 1-2 (título + subtítulo).
     */
    public function header(string $reportName, string $rangeLabel): self
    {
        $sheet = $this->spreadsheet->getActiveSheet();
        $now = CarbonImmutable::now()->format('Y-m-d H:i');

        $sheet->setCellValue('A1', $reportName);
        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(14);

        $sheet->setCellValue('A2', trim($rangeLabel.' · Generado el '.$now, ' ·'));
        $sheet->getStyle('A2')->getFont()->setItalic(true)->setSize(10);

        $this->nextRow = 4;

        return $this;
    }

    /**
     * Escribe la tabla principal: una fila de headers (bold + fill) y N filas de data.
     *
     * @param  list<string>  $headers  Etiquetas de columna.
     * @param  list<list<mixed>>  $rows  Cada sub-array es una fila completa.
     * @param  list<string>  $columnFormats  Formato por columna ('money'|'pct'|'int'|'text'),
     *                                       misma longitud que $headers.
     */
    public function table(array $headers, array $rows, array $columnFormats): self
    {
        if (count($headers) !== count($columnFormats)) {
            throw new \InvalidArgumentException('headers y columnFormats deben tener la misma longitud.');
        }

        $sheet = $this->spreadsheet->getActiveSheet();
        $this->columnFormats = $columnFormats;
        $this->columnCount = count($headers);
        $this->tableHeaderRow = $this->nextRow;

        foreach ($headers as $i => $label) {
            $col = $this->colLetter($i);
            $sheet->setCellValue($col.$this->nextRow, $label);
        }
        $headerRange = $this->colLetter(0).$this->nextRow.':'.$this->colLetter($this->columnCount - 1).$this->nextRow;
        $sheet->getStyle($headerRange)->getFont()->setBold(true);
        $sheet->getStyle($headerRange)->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setARGB(self::HEADER_FILL_COLOR);
        $sheet->getStyle($headerRange)->getBorders()->getBottom()->setBorderStyle(Border::BORDER_THIN);
        $sheet->getStyle($headerRange)->getAlignment()->setHorizontal(Alignment::HORIZONTAL_LEFT);

        $this->nextRow++;

        foreach ($rows as $row) {
            foreach ($row as $i => $value) {
                $col = $this->colLetter($i);
                $cell = $col.$this->nextRow;
                $sheet->setCellValue($cell, $value);
                $this->applyFormat($cell, $columnFormats[$i] ?? self::FORMAT_TEXT);
            }
            $this->nextRow++;
        }

        $this->tableLastDataRow = $this->nextRow - 1;

        // Auto-ancho de columnas.
        for ($i = 0; $i < $this->columnCount; $i++) {
            $sheet->getColumnDimension($this->colLetter($i))->setAutoSize(true);
        }

        return $this;
    }

    /**
     * Footer: una fila final en bold con valores literales por celda.
     * Pasar array vacío significa "no escribir footer" (caso Tarjetas).
     *
     * @param  list<mixed>  $cells  Misma longitud que la tabla; usar '' para celdas vacías.
     */
    public function footer(array $cells): self
    {
        if ($cells === []) {
            return $this;
        }

        $sheet = $this->spreadsheet->getActiveSheet();

        foreach ($cells as $i => $value) {
            $col = $this->colLetter($i);
            $cell = $col.$this->nextRow;
            $sheet->setCellValue($cell, $value);
            // El footer hereda el formato de su columna.
            $this->applyFormat($cell, $this->columnFormats[$i] ?? self::FORMAT_TEXT);
        }

        $footerRange = $this->colLetter(0).$this->nextRow.':'.$this->colLetter(count($cells) - 1).$this->nextRow;
        $sheet->getStyle($footerRange)->getFont()->setBold(true);
        $sheet->getStyle($footerRange)->getBorders()->getTop()->setBorderStyle(Border::BORDER_THIN);

        $this->nextRow++;

        return $this;
    }

    /**
     * Emite el binario xlsx como descarga.
     *
     * Estrategia: escribir a un buffer en memoria, capturar el binario, devolver
     * un StreamedResponse con headers correctos. Esto evita el riesgo de archivo
     * corrupto si el writer falla a media respuesta — la excepción se propaga
     * antes de mandar headers.
     */
    public function download(string $filename): StreamedResponse
    {
        $writer = new Xlsx($this->spreadsheet);
        ob_start();
        $writer->save('php://output');
        $binary = (string) ob_get_clean();

        $safeName = $this->sanitizeFilename($filename);

        return new StreamedResponse(function () use ($binary) {
            echo $binary;
        }, 200, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition' => 'attachment; filename="'.$safeName.'"',
            'Content-Length' => (string) strlen($binary),
            'Cache-Control' => 'no-store, no-cache, must-revalidate',
            'Pragma' => 'no-cache',
        ]);
    }

    /**
     * Devuelve el binario xlsx sin headers HTTP. Útil para tests que necesitan
     * parsear el resultado sin hacer roundtrip de Response.
     */
    public function toBinary(): string
    {
        $writer = new Xlsx($this->spreadsheet);
        ob_start();
        $writer->save('php://output');

        return (string) ob_get_clean();
    }

    /**
     * Carga un xlsx desde un binario en memoria y devuelve el Spreadsheet. Útil
     * en tests para inspeccionar la respuesta.
     */
    public static function loadFromBinary(string $binary): Spreadsheet
    {
        $tmp = tempnam(sys_get_temp_dir(), 'fincore-xlsx-');
        file_put_contents($tmp, $binary);
        try {
            return IOFactory::load($tmp);
        } finally {
            @unlink($tmp);
        }
    }

    private function applyFormat(string $cell, string $format): void
    {
        $code = match ($format) {
            self::FORMAT_MONEY => self::MONEY_FORMAT_CODE,
            self::FORMAT_PCT => self::PCT_FORMAT_CODE,
            self::FORMAT_INT => self::INT_FORMAT_CODE,
            default => null,
        };

        if ($code !== null) {
            $this->spreadsheet->getActiveSheet()
                ->getStyle($cell)
                ->getNumberFormat()
                ->setFormatCode($code);
        }
    }

    private function colLetter(int $index): string
    {
        // Soporte hasta ZZ (suficiente para reportes con decenas de columnas).
        if ($index < 26) {
            return chr(65 + $index);
        }
        $first = intdiv($index, 26) - 1;
        $second = $index % 26;

        return chr(65 + $first).chr(65 + $second);
    }

    private function sanitizeFilename(string $name): string
    {
        $name = preg_replace('/[^A-Za-z0-9_.\-]/', '-', $name) ?? $name;

        return trim($name, '-') ?: 'fincore-export.xlsx';
    }
}
