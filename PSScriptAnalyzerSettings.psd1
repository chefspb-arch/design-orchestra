@{
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Both scripts are interactive CLIs: coloured output and questions to
        # a human are the job, not a side effect. Write-Output would be wrong
        # here - it pollutes the pipeline and breaks `orchestra | ...`.
        'PSAvoidUsingWriteHost'
    )
}
