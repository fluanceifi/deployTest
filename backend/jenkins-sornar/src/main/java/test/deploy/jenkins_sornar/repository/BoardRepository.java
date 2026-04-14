package test.deploy.jenkins_sornar.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import test.deploy.jenkins_sornar.entity.Board;

public interface BoardRepository extends JpaRepository<Board, Long> {
}