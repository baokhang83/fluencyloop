@{
    # FluencyLoop PowerShell lint settings.
    #
    # The scripts are UTF-8 *without* a BOM on purpose: they must byte-match the bash tree's output
    # (state.json, session journals, the calibration profile are all written no-BOM), and the target
    # runtime is PowerShell 7, which reads UTF-8 without a BOM. So the BOM rule is intentionally
    # excluded rather than sprinkling byte-order marks through the tree.
    ExcludeRules = @('PSUseBOMForUnicodeEncodedFile')
}
