# No scan port or test bypass exists in the functional RTL.
# Product integration must decide scan inclusion/exclusion of synchronization
# stages and storage, reset controllability, and test-clock sequencing. Never
# change synchronizer depth or bypass domain-up in functional mode.
error "BLOCKED: async_fifo DFT product profile is not selected"
