package test.deploy.jenkins_sornar.service;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import test.deploy.jenkins_sornar.dto.BoardCreateRequest;
import test.deploy.jenkins_sornar.dto.BoardResponse;
import test.deploy.jenkins_sornar.entity.Board;
import test.deploy.jenkins_sornar.repository.BoardRepository;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    private final BoardRepository boardRepository;

    @Transactional
    public BoardResponse createBoard(BoardCreateRequest request) {
        Board board = Board.builder()
                .title(request.getTitle())
                .content(request.getContent())
                .author(request.getAuthor())
                .build();

        Board savedBoard = boardRepository.save(board);
        return BoardResponse.from(savedBoard);
    }

    public Page<BoardResponse> getBoards(Pageable pageable) {
        return boardRepository.findAll(pageable)
                .map(BoardResponse::from);
    }

    public BoardResponse getBoard(Long id) {
        Board board = boardRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("게시글을 찾을 수 없습니다. ID: " + id));
        return BoardResponse.from(board);
    }
}