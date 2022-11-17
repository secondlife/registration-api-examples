<?php

$config = new PhpCsFixer\Config();
return $config->setRules([
    // PSR-12 is the PHP community's Recommendation for how to format PHP code,
    // like their PEP-8.
    // <https://www.php-fig.org/psr/psr-12/>
    '@PSR12' => true,

    // The Migration rulesets may include rules that aren't available until
    // that target version. For example, @PHP71Migration includes the
    // list_syntax rule, which suggests syntax that requires 7.1 or greater.
    // <https://cs.symfony.com/doc/rules/list_notation/list_syntax.html>
    // We'll wanna upgrade to the target ruleset for the version we're
    // upgrading to *when* we upgrade to that version.
    '@PHP73Migration' => true,

    // "Heredoc/nowdoc content must be properly indented. Requires PHP >= 7.3."
    // The default is to indent the closing symbol of a heredoc to the start
    // plus one level. Turns out this confuses xgettext --lang=php, so localized
    // strings following such a heredoc can't be extracted by the bin/loc/
    // scripts. Use same_as_start instead.
    'heredoc_indentation' => ['indentation' => 'same_as_start'],

    // "Include/Require and file path should be divided with a single space.
    // File path should not be placed under brackets."
    // <https://cs.symfony.com/doc/rules/control_structure/include.html>
    'include' => true,

    // "Replace control structure alternative syntax to use braces."
    // <https://cs.symfony.com/doc/rules/control_structure/no_alternative_syntax.html>
    'no_alternative_syntax' => [
        // "Whether to also fix code with inline HTML."
        'fix_non_monolithic_code' => false,
    ],

    'no_empty_comment' => true,
    'no_unneeded_control_parentheses' => true,
    'no_unused_imports' => true,

    // "There should not be useless else cases." If the other `if`
    // conditions `return` early, then the else block is unwrapped.
    // <https://cs.symfony.com/doc/rules/control_structure/no_useless_else.html>
    'no_useless_else' => true,

    'ordered_imports' => true,

    // Change all single-line # comments to // comments.
    'single_line_comment_style' => ['comment_types' => ['hash']],

    'standardize_not_equals' => true,
    'trim_array_spaces' => true,
]);
