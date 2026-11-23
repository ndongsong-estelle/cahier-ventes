<?php

namespace Database\Seeders;

use App\Models\Question;
use Illuminate\Database\Seeder;

/** Questions courtes par défaut (docs/01). */
class QuestionSeeder extends Seeder
{
    public function run(): void
    {
        Question::updateOrCreate(['id' => 'aide'], [
            'text' => "Est-ce que l'app vous aide ?",
            'kind' => 'choice',
            'choices' => [
                ['value' => 'oui', 'label' => '😀 Oui'],
                ['value' => 'un_peu', 'label' => '😐 Un peu'],
                ['value' => 'non', 'label' => '🙁 Non'],
            ],
            'after_days' => 3,
            'active' => true,
        ]);
        Question::updateOrCreate(['id' => 'manque'], [
            'text' => "Qu'est-ce qui vous manque ?",
            'kind' => 'text',
            'choices' => null,
            'after_days' => 10,
            'active' => true,
        ]);
    }
}
