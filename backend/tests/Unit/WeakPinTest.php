<?php

use App\Support\WeakPin;

it('refuse les codes faciles à deviner', function (string $pin) {
    expect(WeakPin::isWeak($pin))->toBeTrue();
})->with(['0000', '1111', '1234', '4321', '6789', '0123', '1212', '2580', '123', '12345', 'abcd']);

it('accepte les autres codes', function (string $pin) {
    expect(WeakPin::isWeak($pin))->toBeFalse();
})->with(['4826', '7391', '1357', '0921']);
