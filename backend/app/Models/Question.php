<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Question extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['id', 'text', 'kind', 'choices', 'after_days', 'active'];

    protected function casts(): array
    {
        return ['choices' => 'array', 'active' => 'boolean', 'after_days' => 'integer'];
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'text' => $this->text,
            'kind' => $this->kind,
            'choices' => $this->choices,
            'after_days' => $this->after_days,
        ];
    }
}
