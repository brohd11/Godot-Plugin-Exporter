@tool
extends RefCounted
## What a test CI workspace's autorun loads (ReleaseRunner.TEST_JOB): the package's suites through
## util_r's TestRunner, so CI and the editor console's `test` judge suites the same way.

const TestRunner = preload("uid://bcluoc7e06nvj") #! resolve UtilR.Test.TestRunner


static func run(dir:String) -> Dictionary:
	return await TestRunner.run_files(TestRunner.find_suites(dir))
