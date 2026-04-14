package test.deploy.jenkins_sornar.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import test.deploy.jenkins_sornar.dto.BoardCreateRequest;
import test.deploy.jenkins_sornar.dto.BoardResponse;
import test.deploy.jenkins_sornar.service.BoardService;

@RestController
@RequestMapping("/api/boards")
@RequiredArgsConstructor
@Tag(name = "Board API", description = "게시판 관련 API")
public class BoardController {

    private final BoardService boardService;

    @PostMapping
    @Operation(summary = "게시글 생성", description = "새로운 게시글을 생성합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "게시글 생성 성공")
    })
    public ResponseEntity<BoardResponse> createBoard(@Valid @RequestBody BoardCreateRequest request) {
        BoardResponse response = boardService.createBoard(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    @Operation(summary = "게시글 전체 조회", description = "게시글 목록을 페이징 처리하여 조회합니다.")
    public ResponseEntity<Page<BoardResponse>> getBoards(Pageable pageable) {
        return ResponseEntity.ok(boardService.getBoards(pageable));
    }

    @GetMapping("/{id}")
    @Operation(summary = "게시글 상세 조회", description = "ID로 특정 게시글을 상세 조회합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    public ResponseEntity<BoardResponse> getBoard(@PathVariable("id") Long id) {
        return ResponseEntity.ok(boardService.getBoard(id));
    }
}