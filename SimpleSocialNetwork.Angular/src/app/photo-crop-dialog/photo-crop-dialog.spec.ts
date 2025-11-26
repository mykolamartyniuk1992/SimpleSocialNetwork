import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PhotoCropDialog } from './photo-crop-dialog';

describe('PhotoCropDialog', () => {
  let component: PhotoCropDialog;
  let fixture: ComponentFixture<PhotoCropDialog>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PhotoCropDialog]
    })
    .compileComponents();

    fixture = TestBed.createComponent(PhotoCropDialog);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
