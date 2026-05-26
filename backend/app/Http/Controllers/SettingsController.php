<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\HardResetUserData;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SettingsController extends Controller
{
    /**
     * Hard reset: borra físicamente movimientos, cuentas adicionales y plan del
     * usuario. Requiere confirmar con la contraseña actual (acción destructiva e
     * irreversible). El endpoint está scoped por sanctum + verified, así que solo
     * el dueño autenticado puede resetear su propia cuenta.
     */
    public function hardReset(Request $request)
    {
        $data = $request->validate([
            'password' => 'required|string',
            'mode' => ['sometimes', 'string', Rule::in(HardResetUserData::MODES)],
        ]);

        if (! Hash::check($data['password'], $request->user()->password)) {
            throw ValidationException::withMessages([
                'password' => 'La contraseña no es correcta.',
            ]);
        }

        $mode = $data['mode'] ?? HardResetUserData::MODE_FULL;
        $result = HardResetUserData::execute($request->user()->id, $mode);

        return response()->json([
            'message' => 'Cuenta restablecida',
            ...$result,
        ]);
    }
}
