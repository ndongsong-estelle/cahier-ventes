<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/** @extends Factory<User> */
class UserFactory extends Factory
{
    protected static ?string $pinHash;

    public function definition(): array
    {
        return [
            'phone' => '+2376'.fake()->unique()->numerify('########'),
            'shop_name' => 'Boutique '.fake()->firstName(),
            'pin_hash' => static::$pinHash ??= Hash::make('4826'),
        ];
    }
}
