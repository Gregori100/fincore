<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Antes este seeder creaba una cuenta Bolsa global (user_id=null).
        // Con auth real, la Bolsa es singleton-por-usuario y la crea el listener
        // CreateUserBolsaAccount en respuesta al evento Registered.
        // Este seeder queda vacío por diseño; los tests usan UserFactory.
    }
}
