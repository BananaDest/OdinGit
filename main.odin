package main
import "core:fmt"
import "core:mem"
import "core:testing"

Repo :: struct {
	name:         string,
	lastCommitId: int,
	HEAD:         ^Branch,
	branches:     map[string]^Branch,
	arena:        mem.Arena,
}
init_repo :: proc(name: string, size: int = 1024 * 64) -> Repo {

	data := make([]byte, size)
	repo := Repo {
		name         = name,
		lastCommitId = -1,
		branches     = make(map[string]^Branch),
	}

	mem.arena_init(&repo.arena, data)

	allocator := mem.arena_allocator(&repo.arena)
	master := new(Branch, allocator)
	master.name = "master"
	master.commit = nil

	repo.HEAD = master
	repo.branches["master"] = master

	return repo
}
destroy_repo :: proc(repo: ^Repo) {
	delete(repo.branches)
	delete(repo.arena.data)
}
commit_to_repo :: proc(repo: ^Repo, message: string) -> ^Commit {
	allocator := mem.arena_allocator(&repo.arena)
	repo.lastCommitId += 1
	commit := new(Commit, allocator)
	commit.id = repo.lastCommitId
	commit.message = message
	commit.parent = repo.HEAD.commit
	repo.HEAD.commit = commit

	return commit
}
log_commits :: proc(repo: ^Repo) -> [dynamic]^Commit {
	history: [dynamic]^Commit
	current := repo.HEAD.commit
	for current != nil {
		append(&history, current)
		current = current.parent

	}
	return history
}
checkout_to_branch :: proc(repo: ^Repo, branch_name: string) {
	if branch, found := repo.branches[branch_name]; found {
		repo.HEAD = branch
		return
	}
	allocator := mem.arena_allocator(&repo.arena)
	branch := new(Branch, allocator)
	branch.name = branch_name
	branch.commit = repo.HEAD.commit

	repo.HEAD = branch
	repo.branches[branch_name] = branch

}

Commit :: struct {
	id:      int,
	message: string,
	parent:  ^Commit,
}


Branch :: struct {
	name:   string,
	commit: ^Commit,
}

main :: proc() {
}

@(test)
test_log :: proc(t: ^testing.T) {
	repo := init_repo("Repo 1")
	defer destroy_repo(&repo)
	commit_to_repo(&repo, "Firs commit")
	commit_to_repo(&repo, "2 commit")

	commits := log_commits(&repo)
	defer delete(commits)
	testing.expect(t, commits[0].id == 1, "first commit is second")
	testing.expect(t, commits[1].id == 0, "second commit is first")
}

@(test)
test_checkout :: proc(t: ^testing.T) {
	repo := init_repo("test")
	defer destroy_repo(&repo)
	commit_to_repo(&repo, "Initial commit")
	testing.expect(t, repo.HEAD.name == "master", "Should be master")
	checkout_to_branch(&repo, "testing")
	testing.expect(t, repo.HEAD.name == "testing", "Should be testing ")
	checkout_to_branch(&repo, "master")
	testing.expect(t, repo.HEAD.name == "master", "Should be master")
	checkout_to_branch(&repo, "testing")
	testing.expect(t, repo.HEAD.name == "testing", "should be testing")
	checkout_to_branch(&repo, "master")
}


@(test)
test_branches :: proc(t: ^testing.T) {
	repo := init_repo("test")
	defer destroy_repo(&repo)
	commit_to_repo(&repo, "Initial commit")
	commit_to_repo(&repo, "Change 1")

	{
		history := log_commits(&repo)
		defer delete(history)
		testing.expect_value(t, len(history), 2)
		testing.expect_value(t, history[0].id, 1)
		testing.expect_value(t, history[1].id, 0)
	}

	checkout_to_branch(&repo, "testing")
	commit_to_repo(&repo, "Change 2")

	{
		history := log_commits(&repo)
		defer delete(history)
		testing.expect_value(t, len(history), 3)
		testing.expect_value(t, history[0].id, 2)
	}

	checkout_to_branch(&repo, "master")

	{
		history := log_commits(&repo)
		defer delete(history)
		testing.expect_value(t, len(history), 2)
		testing.expect_value(t, history[0].id, 1)
	}
	commit_to_repo(&repo, "change 3")

	{
		history := log_commits(&repo)
		defer delete(history)
		testing.expect_value(t, history[0].id, 3)
		testing.expect_value(t, history[1].id, 1)
	}
}

